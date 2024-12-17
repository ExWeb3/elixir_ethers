defmodule Ethers.Transaction do
  @moduledoc """
  Transaction struct and helper functions for handling EVM transactions.

  This module provides functionality to:
  - Create and manipulate transaction structs
  - Encode transactions for network transmission
  - Handle different transaction types (legacy, EIP-1559, etc.)
  """

  alias Ethers.Transaction.Eip1559
  alias Ethers.Transaction.Legacy
  alias Ethers.Transaction.Protocol, as: TxProtocol
  alias Ethers.Transaction.SignedTransaction
  alias Ethers.Utils

  @callback new(map()) :: {:ok, struct()} | {:error, atom()}
  @callback auto_fetchable_fields() :: [atom()]
  @callback type_envelope() :: non_neg_integer()
  @callback type_id() :: non_neg_integer()

  @default_transaction_type Eip1559

  @type t_transaction :: Eip1559.t() | Legacy.t() | SignedTransaction.t()

  # TODO: Add EIP-2930 and EIP-4844 support
  @transaction_type_modules Application.compile_env(:ethers, :transaction_types, [Legacy, Eip1559])

  @legacy_parity_magic_number 27
  @legacy_parity_with_chain_magic_number 35

  @rpc_fields %{
    access_list: :accessList,
    blob_versioned_hashes: :blobVersionedHashes,
    chain_id: :chainId,
    gas_price: :gasPrice,
    max_fee_per_blob_gas: :maxFeePerBlobGas,
    max_fee_per_gas: :maxFeePerGas,
    max_priority_fee_per_gas: :maxPriorityFeePerGas
  }

  @doc """
  Creates a new transaction struct with the given parameters.

  ## Parameters
    - `params` - Map of transaction parameters
    - `type` - Transaction type (default: `Ethers.Transaction.Eip1559`)

  ## Examples

      iex> Ethers.Transaction.new(%{from: "0x123...", to: "0x456...", value: "0x0"})
      %Ethers.Transaction.Eip1559{from: "0x123...", to: "0x456...", value: "0x0"}
  """
  @spec new(map()) :: {:ok, t_transaction()}
  def new(params) do
    case Map.fetch(params, :type) do
      {:ok, type} when type in @transaction_type_modules ->
        params
        |> type.new()
        |> maybe_wrap_signed(params)

      {:ok, _type} ->
        {:error, :unsupported_transaction_type}

      :error ->
        {:error, :missing_type}
    end
  end

  defp maybe_wrap_signed({:ok, transaction}, params) do
    case Map.fetch(params, :signature_r) do
      {:ok, sig_r} when not is_nil(sig_r) ->
        params
        |> Map.put(:transaction, transaction)
        |> SignedTransaction.new()

      :error ->
        {:ok, transaction}
    end
  end

  defp maybe_wrap_signed({:error, reason}, _params), do: {:error, reason}

  @doc """
  Fills missing transaction fields with default values from the network based on transaction type.

  ## Parameters
    * `params` - Updated Transaction params
    * `opts` - Options to pass to the RPC client

  ## Returns
    * `{:ok, params}` - Filled transaction struct
    * `{:error, reason}` - If fetching defaults fails
  """
  @spec add_auto_fetchable_fields(map(), keyword()) :: {:ok, map()} | {:error, term()}
  def add_auto_fetchable_fields(params, opts) do
    params = Map.put_new(params, :type, @default_transaction_type)

    {keys, actions} =
      params.type.auto_fetchable_fields()
      |> Enum.reject(&Map.get(params, &1))
      |> Enum.map(&{&1, fill_action(&1, params)})
      |> Enum.unzip()

    case actions do
      [] ->
        {:ok, params}

      _ ->
        with {:ok, results} <- Ethers.batch(actions, opts),
             {:ok, results} <- post_process(keys, results, []) do
          {:ok, Map.merge(params, results)}
        end
    end
  end

  @doc """
  Encodes a transaction for network transmission following EIP-155/EIP-1559.

  Handles both legacy and EIP-1559 transaction types, including signature data if present.

  ## Parameters
    * `transaction` - Transaction struct to encode
    * `mode` - Specifies what RLP mode is. `:payload` for encoding the transaction payload,
    `:hash` for encoding the transaction hash

  ## Returns
    * `binary` - RLP encoded transaction with appropriate type envelope
  """
  @spec encode(t_transaction()) :: binary()
  def encode(transaction, mode \\ :payload) do
    transaction
    |> TxProtocol.to_rlp_list(mode)
    |> ExRLP.encode()
    |> prepend_type_envelope(transaction)
  end

  @doc """
  Converts a map (typically from JSON-RPC response) into a Transaction struct.

  Handles different field naming conventions and transaction types.

  ## Parameters
    - `tx` - Map containing transaction data. Keys can be snakeCase strings or atoms.
    (e.g `:chainId`, `"gasPrice"`)

  ## Returns
    - `{:ok, transaction}` - Converted transaction struct
    - `{:error, :unsupported_type}` - If transaction type is not supported
  """
  @spec from_rpc_map(map()) :: {:ok, t_transaction()} | {:error, :unsupported_type}
  def from_rpc_map(tx) do
    with {:ok, type} <- decode_type(from_map_value(tx, :type)) do
      # Convert from RPC-style field names to EVM field names.
      new(%{
        access_list: from_map_value(tx, :accessList),
        block_hash: from_map_value(tx, :blockHash),
        block_number: from_map_value(tx, :blockNumber),
        chain_id: from_map_value(tx, :chainId),
        input: from_map_value(tx, :input),
        from: from_map_value(tx, :from),
        gas: from_map_value(tx, :gas),
        gas_price: from_map_value(tx, :gasPrice),
        hash: from_map_value(tx, :hash),
        max_fee_per_gas: from_map_value(tx, :maxFeePerGas),
        max_priority_fee_per_gas: from_map_value(tx, :maxPriorityFeePerGas),
        nonce: from_map_value(tx, :nonce),
        signature_r: from_map_value(tx, :r),
        signature_s: from_map_value(tx, :s),
        signature_y_parity_or_v: from_map_value(tx, :yParity) || from_map_value(tx, :v),
        to: from_map_value(tx, :to),
        transaction_index: from_map_value(tx, :transactionIndex),
        value: from_map_value(tx, :value),
        type: type
      })
    end
  end

  @doc """
  Calculates the y-parity or v value for transaction signatures.

  Handles both legacy and EIP-1559 transaction types according to their specifications.

  ## Parameters
    - `tx` - Transaction struct
    - `recovery_id` - Recovery ID from the signature

  ## Returns
    - `integer` - Calculated y-parity or v value
  """
  @spec calculate_y_parity_or_v(t_transaction(), binary() | non_neg_integer()) ::
          non_neg_integer()
  def calculate_y_parity_or_v(tx, recovery_id) do
    case tx do
      %Legacy{chain_id: nil} ->
        # EIP-155
        recovery_id + @legacy_parity_magic_number

      %Legacy{chain_id: chain_id} ->
        # EIP-155
        recovery_id + chain_id * 2 + @legacy_parity_with_chain_magic_number

      _tx ->
        # EIP-1559
        recovery_id
    end
  end

  def to_rpc_map(transaction) do
    transaction
    |> then(fn
      %_{} = t -> Map.from_struct(t)
      t -> t
    end)
    |> Enum.map(fn
      {field, "0x" <> _ = value} ->
        {field, value}

      {field, nil} ->
        {field, nil}

      {field, input} when field in [:data, :input, :from, :to] ->
        {field, Utils.hex_encode(input)}

      {field, value} when is_integer(value) ->
        {field, Utils.integer_to_hex(value)}

      {:access_list, al} when is_list(al) ->
        {:access_list, al}

      {:type, type} when is_atom(type) ->
        # Type will get replaced with hex value
        {:type, type}
    end)
    |> Enum.map(fn {field, value} ->
      case Map.fetch(@rpc_fields, field) do
        {:ok, field} -> {field, value}
        :error -> {field, value}
      end
    end)
    |> Map.new()
    |> Map.put(
      :type,
      transaction
      |> TxProtocol.type_id()
      |> Utils.integer_to_hex()
    )
  end

  defp prepend_type_envelope(encoded_tx, transaction) do
    TxProtocol.type_envelope(transaction) <> encoded_tx
  end

  defp fill_action(:chain_id, _tx), do: :chain_id
  defp fill_action(:nonce, tx), do: {:get_transaction_count, tx.from, block: "latest"}
  defp fill_action(:max_fee_per_gas, _tx), do: :gas_price
  defp fill_action(:max_priority_fee_per_gas, _tx), do: :max_priority_fee_per_gas
  defp fill_action(:gas_price, _tx), do: :gas_price
  defp fill_action(:gas, tx), do: {:estimate_gas, tx}

  defp post_process([], [], acc), do: {:ok, Map.new(acc)}

  defp post_process([k | tk], [v | tv], acc) do
    with {:ok, item} <- do_post_process(k, v) do
      post_process(tk, tv, [item | acc])
    end
  end

  defp do_post_process(:max_fee_per_gas, {:ok, max_fee_per_gas}) do
    # Setting a higher value for max_fee_per gas since the actual base fee is
    # determined by the last block. This way we minimize the chance to get stuck in
    # queue when base fee increases
    mex_fee_per_gas = div(max_fee_per_gas * 120, 100)
    {:ok, {:max_fee_per_gas, mex_fee_per_gas}}
  end

  defp do_post_process(:gas, {:ok, gas}) do
    gas = div(gas * 110, 100)
    {:ok, {:gas, gas}}
  end

  defp do_post_process(key, {:ok, v_int}) when is_integer(v_int) do
    {:ok, {key, v_int}}
  end

  defp do_post_process(_key, {:error, reason}), do: {:error, reason}

  defp decode_type("0x" <> _ = type), do: decode_type(Utils.hex_decode!(type))

  Enum.each(@transaction_type_modules, fn module ->
    type_envelope = module.type_envelope()
    defp decode_type(unquote(type_envelope)), do: {:ok, unquote(module)}
  end)

  defp decode_type(<<0>>), do: {:ok, Legacy}
  defp decode_type(nil), do: {:ok, Legacy}
  defp decode_type(_type), do: {:error, :unsupported_type}

  defp from_map_value(tx, key) do
    Map.get_lazy(tx, key, fn -> Map.get(tx, to_string(key)) end)
  end

  @doc false
  @spec default_transaction_type() :: atom()
  def default_transaction_type, do: @default_transaction_type
end
