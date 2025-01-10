defmodule Ethers.Transaction do
  @moduledoc """
  Transaction struct and helper functions for handling EVM transactions.

  This module provides functionality to:
  - Create and manipulate transaction structs
  - Encode transactions for network transmission
  - Handle different transaction types (legacy, EIP-1559, etc.)
  """

  alias Ethers.Transaction.Eip1559
  alias Ethers.Transaction.Eip2930
  alias Ethers.Transaction.Eip4844
  alias Ethers.Transaction.Legacy
  alias Ethers.Transaction.Protocol, as: TxProtocol
  alias Ethers.Transaction.Signed
  alias Ethers.Utils

  @default_transaction_types [Eip1559, Eip2930, Eip4844, Legacy]

  @transaction_types Application.compile_env(
                       :ethers,
                       :transaction_types,
                       @default_transaction_types
                     )

  @default_transaction_type Eip1559

  @rpc_fields %{
    access_list: :accessList,
    blob_versioned_hashes: :blobVersionedHashes,
    chain_id: :chainId,
    gas_price: :gasPrice,
    max_fee_per_blob_gas: :maxFeePerBlobGas,
    max_fee_per_gas: :maxFeePerGas,
    max_priority_fee_per_gas: :maxPriorityFeePerGas
  }

  @typedoc """
  EVM Transaction type
  """
  @type t :: t_payload() | Signed.t()

  @typedoc """
  EVM Transaction payload type
  """
  @type t_payload ::
          unquote(
            @transaction_types
            |> Enum.map(&{{:., [], [{:__aliases__, [alias: false], [&1]}, :t]}, [], []})
            |> Enum.reduce(&{:|, [], [&1, &2]})
          )

  @doc "Creates a new transaction struct with the given parameters."
  @callback new(map()) :: {:ok, t()} | {:error, reason :: atom()}

  @doc "Returns a list of fields that can be auto-fetched from the network."
  @callback auto_fetchable_fields() :: [atom()]

  @doc "Returns the type envelope for the transaction."
  @callback type_envelope() :: binary()

  @doc "Returns the type ID for the transaction. e.g Legacy: 0, EIP-1559: 2"
  @callback type_id() :: non_neg_integer()

  @doc "Constructs a transaction from a decoded RLP list"
  @callback from_rlp_list([binary() | [binary()]]) ::
              {:ok, t(), rest :: [binary() | [binary()]]} | {:error, reason :: term()}

  @doc """
  Creates a new transaction struct with the given parameters.

  Type of transaction is determined by the `type` field in the params map or defaults to EIP-1559.

  ## Examples

      iex> Ethers.Transaction.new(%{type: Ethers.Transaction.Eip1559, from: "0x123...", to: "0x456...", value: "0x0"})
      {:ok, %Ethers.Transaction.Eip1559{from: "0x123...", to: "0x456...", value: "0x0"}}
  """
  @spec new(map()) :: {:ok, t()} | {:error, reason :: term()}
  def new(params) do
    case Map.fetch(params, :type) do
      {:ok, type} when type in @transaction_types ->
        input =
          params
          |> Map.get(:input, Map.get(params, :data))
          |> Utils.hex_decode!()

        params
        |> Map.put(:input, input)
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
        |> Map.put(:payload, transaction)
        |> Signed.new()

      :error ->
        {:ok, transaction}
    end
  end

  defp maybe_wrap_signed({:error, reason}, _params), do: {:error, reason}

  @doc """
  Fills missing transaction fields with default values from the network based on transaction type.

  ## Parameters
    - `params` - Updated Transaction params
    - `opts` - Options to pass to the RPC client

  ## Returns
    - `{:ok, params}` - Filled transaction struct
    - `{:error, reason}` - If fetching defaults fails
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
    - `transaction` - Transaction struct to encode

  ## Returns
    - `binary` - RLP encoded transaction with appropriate type envelope
  """
  @spec encode(t()) :: binary()
  def encode(%mod{} = transaction) do
    mode = if mod == Signed, do: :payload, else: :hash

    transaction
    |> TxProtocol.to_rlp_list(mode)
    |> ExRLP.encode()
    |> prepend_type_envelope(transaction)
  end

  @doc """
  Decodes a raw transaction from a binary or hex-encoded string.

  Transaction strings must be prefixed with "0x" for hex-encoded inputs.
  Handles both legacy and typed transactions (EIP-1559, etc).

  ## Parameters
    - `raw_transaction` - Raw transaction data as a binary or hex string starting with "0x"

  ## Returns
    - `{:ok, transaction}` - Decoded transaction struct
    - `{:error, reason}` - Error decoding transaction
  """
  @spec decode(String.t() | binary()) :: {:ok, t()} | {:error, term()}
  def decode("0x" <> raw_transaction) do
    case Utils.hex_decode(raw_transaction) do
      {:ok, hex_decoded} -> decode(hex_decoded)
      :error -> {:error, :invalid_hex}
    end
  end

  def decode(raw_transaction_bin) when is_binary(raw_transaction_bin) do
    case decode_transaction_data(raw_transaction_bin) do
      {:ok, transaction, signature} ->
        maybe_decode_signature(transaction, signature)

      {:error, reason} ->
        {:error, reason}
    end
  end

  Enum.each(@transaction_types, fn module ->
    type_envelope = module.type_envelope()

    defp decode_transaction_data(<<unquote(type_envelope)::binary, rest::binary>>) do
      rlp_decoded = ExRLP.decode(rest)
      unquote(module).from_rlp_list(rlp_decoded)
    end
  end)

  defp decode_transaction_data(legacy_transaction) when is_binary(legacy_transaction) do
    rlp_decoded = ExRLP.decode(legacy_transaction)

    Legacy.from_rlp_list(rlp_decoded)
  end

  defp maybe_decode_signature(transaction, rlp_list) do
    case Signed.from_rlp_list(rlp_list, transaction) do
      {:ok, signed_transaction} -> {:ok, signed_transaction}
      {:error, :no_signature} -> {:ok, transaction}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Calculates the transaction hash.

  ## Parameters
  - `transaction` - Transaction struct to hash
  - `format` - Format to return the hash in. Either `:hex` or `:bin`. (default: `:hex`)

  ## Returns Either
  - `binary` - Transaction hash in binary format (when `format` is `:bin`)
  - `String.t()` - Transaction hash in hex format prefixed with "0x" (when `format` is `:hex`)
  """
  @spec transaction_hash(t(), :bin | :hex) :: binary() | String.t()
  def transaction_hash(transaction, format \\ :hex) do
    hash_bin =
      transaction
      |> encode()
      |> Ethers.keccak_module().hash_256()

    case format do
      :bin -> hash_bin
      :hex -> Utils.hex_encode(hash_bin)
    end
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
  @spec from_rpc_map(map()) :: {:ok, t()} | {:error, :unsupported_type}
  def from_rpc_map(tx) do
    with {:ok, type} <- decode_type(from_map_value(tx, :type)) do
      # Convert from RPC-style field names to EVM field names.
      new(%{
        access_list: from_map_value(tx, :accessList),
        blob_versioned_hashes: from_map_value(tx, :blobVersionedHashes),
        block_hash: from_map_value(tx, :blockHash),
        block_number: from_map_value_int(tx, :blockNumber),
        chain_id: from_map_value_int(tx, :chainId),
        input: from_map_value(tx, :input) || from_map_value(tx, :data),
        from: from_map_value(tx, :from),
        gas: from_map_value_int(tx, :gas),
        gas_price: from_map_value_int(tx, :gasPrice),
        hash: from_map_value(tx, :hash),
        max_fee_per_blob_gas: from_map_value_int(tx, :maxFeePerBlobGas),
        max_fee_per_gas: from_map_value_int(tx, :maxFeePerGas),
        max_priority_fee_per_gas: from_map_value_int(tx, :maxPriorityFeePerGas),
        nonce: from_map_value_int(tx, :nonce),
        signature_r: from_map_value_bin(tx, :r),
        signature_s: from_map_value_bin(tx, :s),
        signature_y_parity_or_v: from_map_value_int(tx, :yParity) || from_map_value_int(tx, :v),
        to: from_map_value(tx, :to),
        transaction_index: from_map_value_int(tx, :transactionIndex),
        value: from_map_value_int(tx, :value),
        type: type
      })
    end
  end

  @doc """
  Converts a Transaction struct into a map suitable for JSON-RPC.

  ## Parameters
  - `transaction` - Transaction struct to convert

  ## Returns
  - map containing transaction parameters with RPC field names and "0x" prefixed hex values
  """
  @spec to_rpc_map(t()) :: map()
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

  @doc false
  @deprecated "Use Transaction.Signed.calculate_y_parity_or_v/2 instead"
  defdelegate calculate_y_parity_or_v(tx, recovery_id), to: Signed

  defp prepend_type_envelope(encoded_tx, transaction) do
    TxProtocol.type_envelope(transaction) <> encoded_tx
  end

  defp fill_action(:chain_id, _tx), do: :chain_id
  defp fill_action(:nonce, tx), do: {:get_transaction_count, tx.from, block: "latest"}
  defp fill_action(:max_fee_per_gas, _tx), do: :gas_price
  defp fill_action(:max_priority_fee_per_gas, _tx), do: :max_priority_fee_per_gas
  defp fill_action(:max_fee_per_blob_gas, _tx), do: :blob_base_fee
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

  Enum.each(@transaction_types, fn module ->
    type_envelope = module.type_envelope()
    defp decode_type(unquote(type_envelope)), do: {:ok, unquote(module)}
  end)

  defp decode_type(<<0>>), do: {:ok, Legacy}
  defp decode_type(nil), do: {:ok, Legacy}
  defp decode_type(_type), do: {:error, :unsupported_type}

  defp from_map_value_bin(tx, key) do
    case from_map_value(tx, key) do
      nil -> nil
      hex -> Utils.hex_decode!(hex)
    end
  end

  defp from_map_value_int(tx, key) do
    case from_map_value(tx, key) do
      nil -> nil
      hex -> Utils.hex_to_integer!(hex)
    end
  end

  defp from_map_value(tx, key) do
    Map.get_lazy(tx, key, fn -> Map.get(tx, to_string(key)) end)
  end

  @doc false
  def default_transaction_type, do: @default_transaction_type
end
