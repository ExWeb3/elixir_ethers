defmodule Ethers.Transaction do
  @moduledoc """
  Transaction struct and helper functions for handling EVM transactions.

  This module provides functionality to:
  - Create and manipulate transaction structs
  - Encode transactions for network transmission
  - Handle different transaction types (legacy, EIP-1559, etc.)
  """

  alias Ethers.Types
  alias Ethers.Utils

  @enforce_keys [:type]
  defstruct [
    :type,
    access_list: [],
    block_hash: nil,
    block_number: nil,
    chain_id: nil,
    data: "",
    from: nil,
    gas: nil,
    gas_price: nil,
    hash: nil,
    max_fee_per_gas: nil,
    max_priority_fee_per_gas: nil,
    nonce: nil,
    signature_r: nil,
    signature_s: nil,
    signature_y_parity_or_v: nil,
    to: nil,
    transaction_index: nil,
    value: "0x0"
  ]

  @type t_transaction_type :: :legacy | :eip1559 | :eip2930 | :eip4844
  @type t :: %__MODULE__{
          access_list: [{binary(), [binary()]}],
          block_hash: binary() | nil,
          block_number: binary() | nil,
          chain_id: binary() | nil,
          data: binary(),
          from: Types.t_address() | nil,
          gas: binary() | nil,
          gas_price: binary() | nil,
          hash: binary() | nil,
          max_fee_per_gas: binary() | nil,
          max_priority_fee_per_gas: binary(),
          nonce: binary() | nil,
          signature_r: binary() | nil,
          signature_s: binary() | nil,
          signature_y_parity_or_v: binary() | non_neg_integer() | nil,
          to: Types.t_address() | nil,
          transaction_index: binary() | nil,
          type: t_transaction_type(),
          value: binary()
        }

  @transaction_envelope_types %{eip1559: <<2>>, eip2930: <<1>>, eip4844: <<3>>, legacy: <<>>}
  @legacy_parity_magic_number 27
  @legacy_parity_with_chain_magic_number 35
  @common_fillable_params [:chain_id, :nonce]
  @type_fillable_params %{
    legacy: [:gas_price],
    eip1559: [:max_fee_per_gas, :max_priority_fee_per_gas]
  }
  @integer_type_values [
    :block_number,
    :chain_id,
    :gas,
    :gas_price,
    :max_fee_per_gas,
    :max_priority_fee_per_gas,
    :nonce,
    :signature_y_parity_or_v,
    :transaction_index,
    :value
  ]
  @binary_type_values [:data, :signature_r, :signature_s]

  defguardp has_value(v) when not is_nil(v) and v != "" and v != "0x"

  @doc """
  Creates a new transaction struct with the given parameters.

  ## Parameters
    - `params` - Map of transaction parameters
    - `type` - Transaction type (default: `:eip1559`)

  ## Examples

      iex> Ethers.Transaction.new(%{from: "0x123...", to: "0x456...", value: "0x0"})
      %Ethers.Transaction{type: :eip1559, from: "0x123...", to: "0x456...", value: "0x0"}
  """
  @spec new(map(), t_transaction_type()) :: t()
  def new(params, type \\ :eip1559) do
    struct!(__MODULE__, Map.put(params, :type, type))
  end

  @doc """
  Fills missing transaction fields with default values from the network.

  This function will attempt to fetch appropriate values for:
  - chain_id
  - nonce
  - gas_price (for legacy transactions)
  - max_fee_per_gas and max_priority_fee_per_gas (for EIP-1559 transactions)

  ## Parameters
    * `tx` - Transaction struct to fill
    * `opts` - Options to pass to the RPC client

  ## Returns
    * `{:ok, transaction}` - Filled transaction struct
    * `{:error, reason}` - If fetching defaults fails
  """
  @spec fill_with_defaults(t(), keyword()) :: {:ok, t()} | {:error, term()}
  def fill_with_defaults(%__MODULE__{type: type} = tx, opts) do
    {keys, actions} =
      tx
      |> Map.from_struct()
      |> Map.take(@common_fillable_params ++ Map.fetch!(@type_fillable_params, type))
      |> Enum.filter(fn {_k, v} -> is_nil(v) end)
      |> Enum.map(&elem(&1, 0))
      |> Enum.map(&{&1, fill_action(&1, tx)})
      |> Enum.filter(&elem(&1, 1))
      |> Enum.unzip()

    if actions == [] do
      {:ok, tx}
    else
      with {:ok, results} <- Ethers.batch(actions, opts),
           {:ok, defaults} <- post_process(keys, results, []) do
        {:ok, Map.merge(tx, defaults)}
      end
    end
  end

  @doc """
  Encodes a transaction for network transmission following EIP-155/EIP-1559.

  Handles both legacy and EIP-1559 transaction types, including signature data if present.

  ## Parameters
    * `transaction` - Transaction struct to encode

  ## Returns
    * `binary` - RLP encoded transaction with appropriate type envelope
  """
  @spec encode(t()) :: binary()
  def encode(%__MODULE__{type: type} = transaction) do
    transaction
    |> to_rlp_list()
    |> maybe_append_signature(transaction)
    |> ExRLP.encode()
    |> prepend_type_envelope(type)
  end

  @doc """
  Converts a map (typically from JSON-RPC response) into a Transaction struct.

  Handles different field naming conventions and transaction types.

  ## Parameters
    - `tx` - Map containing transaction data. Keys can be snakeCase strings or atoms.
    (e.g `:chainId`, `"gasPrice"`)

  ## Returns
    - `{:ok, transaction}` - Converted transaction struct
    - `{:error, :unsupported_tx_type}` - If transaction type is not supported
  """
  @spec from_map(map()) :: {:ok, t()} | {:error, :unsupported_tx_type}
  def from_map(tx) do
    with {:ok, tx_type} <- decode_tx_type(from_map_value(tx, :type)) do
      tx_struct =
        %{
          access_list: from_map_value(tx, :accessList),
          block_hash: from_map_value(tx, :blockHash),
          block_number: from_map_value(tx, :blockNumber),
          chain_id: from_map_value(tx, :chainId),
          data: from_map_value(tx, :input),
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
          value: from_map_value(tx, :value)
        }
        |> new(tx_type)

      {:ok, tx_struct}
    end
  end

  @doc """
  Converts a Transaction struct to a map suitable for JSON-RPC requests.

  Different transaction types (legacy vs EIP-1559) will produce different map structures.

  ## Parameters
    - `tx` - Transaction struct to convert

  ## Returns
    - `map` - Transaction data in JSON-RPC format
  """
  @spec to_map(t()) :: map()
  def to_map(%{type: :eip1559} = tx) do
    %{
      from: tx.from,
      to: tx.to,
      gas: tx.gas,
      maxPriorityFeePerGas: tx.max_priority_fee_per_gas,
      maxFeePerGas: tx.max_fee_per_gas,
      nonce: tx.nonce,
      value: tx.value,
      data: tx.data
    }
  end

  def to_map(%{type: :legacy} = tx) do
    %{
      from: tx.from,
      to: tx.to,
      gas: tx.gas,
      gasPrice: tx.gas_price,
      nonce: tx.nonce,
      value: tx.value,
      data: tx.data
    }
  end

  @doc """
  Decodes hexadecimal values in a transaction struct to their native types.

  Converts:
  - Integer fields from hex to integers
  - Binary fields from hex to raw binary
  - Leaves other fields unchanged

  ## Parameters
    - `tx` - Transaction struct to decode

  ## Returns
    - `map` - Map with decoded values
  """
  @spec decode_values(t()) :: map()
  def decode_values(%__MODULE__{} = tx) do
    tx
    |> Map.from_struct()
    |> Map.new(fn
      {k, nil} -> {k, nil}
      {k, ""} -> {k, nil}
      {k, v} when k in @integer_type_values -> {k, Utils.hex_to_integer!(v)}
      {k, v} when k in @binary_type_values -> {k, Utils.hex_decode!(v)}
      {k, v} -> {k, v}
    end)
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
  @spec calculate_y_parity_or_v(t(), binary() | non_neg_integer()) :: non_neg_integer()
  def calculate_y_parity_or_v(tx, recovery_id) when has_value(recovery_id) do
    case tx do
      %{type: :legacy, chain_id: chain_id} when has_value(chain_id) ->
        # EIP-155
        chain_id = Utils.hex_to_integer!(chain_id)
        recovery_id + @legacy_parity_with_chain_magic_number + chain_id * 2

      %{type: :legacy} ->
        # EIP-155
        recovery_id + @legacy_parity_magic_number

      _ ->
        # EIP-1559
        recovery_id
    end
  end

  defp maybe_append_signature(tx_list, tx) do
    case tx do
      %{signature_r: r, signature_s: s, signature_y_parity_or_v: y_parity}
      when has_value(r) and has_value(s) and has_value(y_parity) ->
        tx_list ++
          [Utils.hex_to_integer!(y_parity), Utils.hex_to_integer!(r), Utils.hex_to_integer!(s)]

      %{type: :legacy, chain_id: chain_id} when not is_nil(chain_id) ->
        # EIP-155 encoding for signature mitigation intra-chain replay attack
        tx_list ++ [Utils.hex_to_integer!(chain_id), 0, 0]

      _ ->
        tx_list
    end
  end

  defp to_rlp_list(%{type: :eip1559} = tx) do
    [
      Utils.hex_to_integer!(tx.chain_id),
      Utils.hex_to_integer!(tx.nonce),
      Utils.hex_to_integer!(tx.max_priority_fee_per_gas),
      Utils.hex_to_integer!(tx.max_fee_per_gas),
      Utils.hex_to_integer!(tx.gas),
      hex_decode(tx.to),
      Utils.hex_to_integer!(tx.value),
      hex_decode(tx.data),
      hex_decode(tx.access_list || [])
    ]
  end

  defp to_rlp_list(%{type: :legacy} = tx) do
    [
      Utils.hex_to_integer!(tx.nonce),
      Utils.hex_to_integer!(tx.gas_price),
      Utils.hex_to_integer!(tx.gas),
      hex_decode(tx.to),
      Utils.hex_to_integer!(tx.value),
      hex_decode(tx.data)
    ]
  end

  defp to_rlp_list(%{type: type}) do
    raise "Ethers does not support encoding of #{inspect(type)} transactions"
  end

  defp prepend_type_envelope(tx_data, type) do
    Map.fetch!(@transaction_envelope_types, type) <> tx_data
  end

  defp fill_action(:chain_id, _tx), do: :chain_id
  defp fill_action(:nonce, tx), do: {:get_transaction_count, tx.from, block: "latest"}
  defp fill_action(:max_fee_per_gas, _tx), do: :gas_price
  defp fill_action(:max_priority_fee_per_gas, _tx), do: :max_priority_fee_per_gas
  defp fill_action(:gas_price, _tx), do: :gas_price

  defp post_process([], [], acc), do: {:ok, Enum.into(acc, %{})}

  defp post_process([k | tk], [v | tv], acc) do
    with {:ok, item} <- do_post_process(k, v) do
      post_process(tk, tv, [item | acc])
    end
  end

  defp do_post_process(:chain_id, {:ok, v_int}) when is_integer(v_int) do
    {:ok, {:chain_id, Utils.integer_to_hex(v_int)}}
  end

  defp do_post_process(:max_fee_per_gas, {:ok, v_hex}) do
    with {:ok, v} <- Utils.hex_to_integer(v_hex) do
      # Setting a higher value for max_fee_per gas since the actual base fee is
      # determined by the last block. This way we minimize the chance to get stuck in
      # queue when base fee increases
      mex_fee_per_gas = div(v * 120, 100)
      {:ok, {:max_fee_per_gas, Utils.integer_to_hex(mex_fee_per_gas)}}
    end
  end

  defp do_post_process(:max_priority_fee_per_gas, {:ok, v_int}) do
    # use latest max_priority_fee_per_gas from the chain as default
    {:ok, {:max_priority_fee_per_gas, Utils.integer_to_hex(v_int)}}
  end

  defp do_post_process(:nonce, {:ok, nonce}) when is_integer(nonce) do
    {:ok, {:nonce, Utils.integer_to_hex(nonce)}}
  end

  defp do_post_process(key, {:ok, v_hex}) do
    {:ok, {key, v_hex}}
  end

  defp do_post_process(_key, {:error, reason}), do: {:error, reason}

  defp hex_decode(nil), do: ""
  defp hex_decode(""), do: ""
  defp hex_decode("0x"), do: ""

  defp hex_decode("0x" <> _ = bin) do
    Utils.hex_decode!(bin)
  end

  defp hex_decode(list) when is_list(list) do
    Enum.map(list, &hex_decode/1)
  end

  defp decode_tx_type("0x" <> _ = type), do: decode_tx_type(Utils.hex_decode!(type))

  Enum.each(@transaction_envelope_types, fn {name, value} ->
    defp decode_tx_type(unquote(value)), do: {:ok, unquote(name)}
  end)

  defp decode_tx_type(<<0>>), do: {:ok, :legacy}
  defp decode_tx_type(nil), do: {:ok, :legacy}
  defp decode_tx_type(_type), do: {:error, :unsupported_tx_type}

  defp from_map_value(tx, key) do
    Map.get_lazy(tx, key, fn -> Map.get(tx, to_string(key)) end)
  end
end
