defmodule Ethers.Transaction.Unknown do
  @moduledoc """
  Transaction of a type that is not registered, kept undecoded.

  Without the type's layout only the type id is known, so this struct keeps the transaction as it
  was read for the type specific code to use. It is returned for a transaction type without a
  registered module, like the chain specific types of L2s (for example OP-stack deposit
  transactions, type `0x7e`):

  - `Ethers.Transaction.from_rpc_map/1`, and so `Ethers.get_transaction/2`, keep the JSON-RPC
    transaction object in `rpc_map` and its block metadata in `metadata`.
  - `Ethers.Transaction.decode/1` keeps the
    [EIP-2718](https://eips.ethereum.org/EIPS/eip-2718) `TransactionPayload` (the bytes after the
    type byte) in `raw_payload`.

  ```elixir
  {:ok, %Ethers.Transaction.Unknown{type_id: 0x7E, rpc_map: rpc_map}} =
    Ethers.get_transaction(tx_hash)

  rpc_map["from"]
  #=> "0xdeaddeaddeaddeaddeaddeaddeaddeaddead0001"

  rpc_map["sourceHash"]
  #=> "0x817dce692d94a9f2a738f9856f0faf3a942260a5d51684a5ac3823f5f1542f44"
  ```

  A transaction decoded from bytes encodes back to the same bytes with
  `Ethers.Transaction.encode/1`, and `Ethers.Transaction.transaction_hash/2` returns the keccak
  hash of them. One read from an RPC map cannot be encoded or hashed (the hash reported by the
  node is in `rpc_map["hash"]`), and neither can be signed or converted with
  `Ethers.Transaction.to_rpc_map/1`: these raise `ArgumentError`.

  Types listed in the compile-time `:transaction_types` config of `:ethers` are decoded by their
  module instead.
  """

  alias Ethers.Transaction.Metadata
  alias Ethers.Utils

  @enforce_keys [:type_id]
  defstruct [:type_id, :rpc_map, :raw_payload, :metadata]

  @typedoc """
  A transaction of an unregistered type with the following fields:
  - `type_id` - the transaction type (e.g. `0x7E`)
  - `rpc_map` - the JSON-RPC transaction object, unchanged (addresses keep the node's casing),
    when read with `Ethers.Transaction.from_rpc_map/1`
  - `raw_payload` - the EIP-2718 `TransactionPayload`, undecoded, when read with
    `Ethers.Transaction.decode/1`
  - `metadata` - block metadata (block hash, block number and transaction index) from the RPC
    map, like `Ethers.Transaction.Signed` carries for registered types. A value that is missing or
    not valid for its field is nil (it is still in `rpc_map`)
  """
  @type t :: %__MODULE__{
          type_id: non_neg_integer(),
          rpc_map: map() | nil,
          raw_payload: binary() | nil,
          metadata: Metadata.t() | nil
        }

  @doc false
  @spec from_rpc_map(map(), non_neg_integer()) :: t()
  def from_rpc_map(rpc_map, type_id) do
    %__MODULE__{
      type_id: type_id,
      rpc_map: rpc_map,
      metadata: %Metadata{
        block_hash: rpc_map |> from_map_value(:blockHash) |> decode_hash(),
        block_number: rpc_map |> from_map_value(:blockNumber) |> decode_quantity(),
        transaction_index: rpc_map |> from_map_value(:transactionIndex) |> decode_quantity()
      }
    }
  end

  @doc false
  @spec raise_unsupported(t(), String.t()) :: no_return()
  def raise_unsupported(%__MODULE__{type_id: type_id}, reason) do
    raise ArgumentError,
          "Unsupported transaction type #{Utils.integer_to_hex(type_id)}: #{reason}"
  end

  defp from_map_value(rpc_map, key) do
    Map.get_lazy(rpc_map, key, fn -> Map.get(rpc_map, to_string(key)) end)
  end

  defp decode_quantity("0x" <> _ = quantity) do
    case Utils.hex_to_integer(quantity) do
      {:ok, integer} -> integer
      {:error, :invalid_hex} -> nil
    end
  end

  defp decode_quantity(_invalid), do: nil

  defp decode_hash(<<"0x", hex::binary-64>> = hash) do
    case Utils.hex_decode(hex) do
      {:ok, _hash_bin} -> hash
      :error -> nil
    end
  end

  defp decode_hash(_invalid), do: nil

  defimpl Ethers.Transaction.Protocol do
    def type_id(transaction), do: transaction.type_id

    def type_envelope(%{type_id: type_id}) when type_id in 0..0x7F, do: <<type_id>>

    def type_envelope(transaction),
      do: @for.raise_unsupported(transaction, "not an EIP-2718 transaction type")

    @dialyzer {:no_return, {:to_rlp_list, 2}}
    def to_rlp_list(transaction, _mode) do
      @for.raise_unsupported(
        transaction,
        "#{inspect(@for)} cannot be signed or converted to an RLP list"
      )
    end
  end
end
