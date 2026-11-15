defmodule Ethers.Transaction.Unknown do
  @moduledoc """
  Read-only transaction of a type that is not registered, as read from a JSON-RPC response.

  `Ethers.Transaction.from_rpc_map/1`, and so `Ethers.get_transaction/2`, return this struct for
  a transaction type without a registered module, like the chain specific types of L2s (for
  example OP-stack deposit transactions, type `0x7e`). The fields every transaction has are
  decoded where present and `raw` keeps the original map for the type specific fields.

  ```elixir
  {:ok, %Ethers.Transaction.Unknown{type_id: 0x7E} = transaction} =
    Ethers.get_transaction(tx_hash)

  transaction.from
  #=> "0xDeaDDEaDDeAdDeAdDEAdDEaddeAddEAdDEAd0001"

  transaction.raw["sourceHash"]
  #=> "0x817dce692d94a9f2a738f9856f0faf3a942260a5d51684a5ac3823f5f1542f44"
  ```

  Without the type's layout the transaction cannot be encoded, so `Ethers.Transaction.encode/1`,
  `Ethers.Transaction.transaction_hash/2` and `Ethers.Transaction.to_rpc_map/1` raise
  `ArgumentError` for it. Its `hash` and `from` are the ones reported by the node.

  Types listed in the compile-time `:transaction_types` config of `:ethers` are decoded by their
  module instead.
  """

  alias Ethers.Transaction.Metadata
  alias Ethers.Types
  alias Ethers.Utils

  @enforce_keys [:type_id, :raw]
  defstruct [
    :type_id,
    :hash,
    :from,
    :to,
    :nonce,
    :value,
    :gas,
    :input,
    :chain_id,
    :metadata,
    :raw
  ]

  @typedoc """
  A transaction of an unregistered type with the following fields:
  - `type_id` - the transaction type (e.g. `0x7E`)
  - `hash` - transaction hash, as reported by the node
  - `from` - sender address (EIP-55 checksummed), as reported by the node
  - `to` - destination address (EIP-55 checksummed), nil for contract creation
  - `nonce` - sequence number for the transaction from this sender
  - `value` - amount of ether (in wei) to transfer
  - `gas` - maximum amount of gas allowed for transaction execution
  - `input` - data payload of the transaction
  - `chain_id` - chain ID of network where the transaction is executed
  - `metadata` - block metadata (block hash, block number and transaction index), like
    `Ethers.Transaction.Signed` carries for registered types
  - `raw` - the original JSON-RPC map, unchanged

  A field is nil when the map does not have it or its value is not valid for the field (the value
  is still in `raw`). The signature (`r`, `s`, `v` and `yParity`) is only kept in `raw`: it may be
  missing or a placeholder (OP-stack deposit transactions report zeros) and cannot be verified
  without the type's signing payload.
  """
  @type t :: %__MODULE__{
          type_id: non_neg_integer(),
          hash: Types.t_hash() | nil,
          from: Types.t_address() | nil,
          to: Types.t_address() | nil,
          nonce: non_neg_integer() | nil,
          value: non_neg_integer() | nil,
          gas: non_neg_integer() | nil,
          input: binary() | nil,
          chain_id: non_neg_integer() | nil,
          metadata: Metadata.t() | nil,
          raw: map()
        }

  @doc false
  @spec from_rpc_map(map(), non_neg_integer()) :: t()
  def from_rpc_map(tx, type_id) do
    %__MODULE__{
      type_id: type_id,
      hash: tx |> from_map_value(:hash) |> decode_hash(),
      from: tx |> from_map_value(:from) |> decode_address(),
      to: tx |> from_map_value(:to) |> decode_address(),
      nonce: tx |> from_map_value(:nonce) |> decode_quantity(),
      value: tx |> from_map_value(:value) |> decode_quantity(),
      gas: tx |> from_map_value(:gas) |> decode_quantity(),
      input: decode_data(from_map_value(tx, :input)) || decode_data(from_map_value(tx, :data)),
      chain_id: tx |> from_map_value(:chainId) |> decode_quantity(),
      metadata: %Metadata{
        block_hash: tx |> from_map_value(:blockHash) |> decode_hash(),
        block_number: tx |> from_map_value(:blockNumber) |> decode_quantity(),
        transaction_index: tx |> from_map_value(:transactionIndex) |> decode_quantity()
      },
      raw: tx
    }
  end

  @doc false
  @spec raise_read_only(t(), String.t()) :: no_return()
  def raise_read_only(%__MODULE__{type_id: type_id}, operation) do
    raise ArgumentError,
          "Unsupported transaction type #{Utils.integer_to_hex(type_id)}: " <>
            "#{inspect(__MODULE__)} is read-only and cannot be #{operation}"
  end

  defp from_map_value(tx, key) do
    Map.get_lazy(tx, key, fn -> Map.get(tx, to_string(key)) end)
  end

  defp decode_quantity("0x" <> _ = quantity) do
    case Utils.hex_to_integer(quantity) do
      {:ok, integer} -> integer
      {:error, :invalid_hex} -> nil
    end
  end

  defp decode_quantity(_invalid), do: nil

  defp decode_data("0x" <> _ = data) do
    case Utils.hex_decode(data) do
      {:ok, binary} -> binary
      :error -> nil
    end
  end

  defp decode_data(_invalid), do: nil

  defp decode_address(<<prefix::binary-2, hex::binary-40>> = address)
       when prefix in ["0x", "0X"] do
    case Utils.hex_decode(hex) do
      {:ok, _address_bin} -> Utils.to_checksum_address(address)
      :error -> nil
    end
  end

  defp decode_address(_invalid), do: nil

  defp decode_hash(<<"0x", _hex::binary-64>> = hash) do
    if decode_data(hash), do: hash
  end

  defp decode_hash(_invalid), do: nil

  defimpl Ethers.Transaction.Protocol do
    def type_id(transaction), do: transaction.type_id

    @dialyzer {:no_return, {:type_envelope, 1}}
    def type_envelope(transaction), do: @for.raise_read_only(transaction, "encoded")

    @dialyzer {:no_return, {:to_rlp_list, 2}}
    def to_rlp_list(transaction, _mode), do: @for.raise_read_only(transaction, "encoded")
  end
end
