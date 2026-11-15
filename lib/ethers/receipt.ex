defmodule Ethers.Receipt do
  @moduledoc """
  Receipt of a transaction included in a block, as returned by
  `Ethers.get_transaction_receipt/2` (the `eth_getTransactionReceipt` RPC method).

  The fields are the members of the `ReceiptInfo` schema of the
  [Ethereum execution APIs](https://github.com/ethereum/execution-apis/blob/main/src/schemas/receipt.yaml),
  named after the snake case of their RPC member names. See `t:t/0` for the fields and how
  each of them is decoded.

  Decoding rules:

  - Quantities are decoded to integers, including `type` (the
    [EIP-2718](https://eips.ethereum.org/EIPS/eip-2718) transaction type id).
  - `status` is decoded to `:success` or `:failure`.
  - Addresses are checksummed.
  - Hashes are kept as returned by the node: `0x` prefixed hex strings.
  - `logs_bloom` is decoded to a binary.
  - `logs` are kept as returned by the node, see [Logs](#module-logs).
  - A member the node omits is `nil` (e.g. `status` of a pre-Byzantium receipt, or
    `blob_gas_used` of a non-blob transaction).
  - Members not defined by the schema are ignored. Chain specific members (e.g. the L1 fee
    members of OP Stack chains) are available in `raw`, the receipt exactly as returned by the
    node.

  `Ethers.get_transaction_receipt/2` returns `{:error, {:invalid_receipt_member, member}}`
  when the node returns a member that does not match the schema (e.g. a `status` other than
  `"0x0"` or `"0x1"`), with `member` the RPC member name (e.g. `"status"`).

  ## Logs

  A receipt holds the logs of every contract the transaction called, and decoding a log
  requires the ABI of its event. The logs are therefore kept as returned by the node (maps
  with string keys, the form `Ethers.Event.decode/2` and `Ethers.Event.find_and_decode/2`
  accept).

  ## Example

      {:ok, receipt} = Ethers.get_transaction_receipt(tx_hash)

      %Ethers.Receipt{
        block_hash: "0x5f3a...3b20",
        block_number: 21563820,
        contract_address: nil,
        cumulative_gas_used: 7014293,
        effective_gas_price: 7349186131,
        from: "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045",
        gas_used: 45029,
        logs: [%{"address" => "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48", ...}],
        logs_bloom: <<0, 0, 0, ...>>,
        status: :success,
        to: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
        transaction_hash: "0x9c4e...6e5d",
        transaction_index: 94,
        type: 2,
        raw: %{"blockHash" => "0x5f3a...3b20", "status" => "0x1", ...},
        ...
      }
  """

  alias Ethers.Types
  alias Ethers.Utils

  defstruct [
    :blob_gas_price,
    :blob_gas_used,
    :block_hash,
    :block_number,
    :contract_address,
    :cumulative_gas_used,
    :effective_gas_price,
    :from,
    :gas_used,
    :logs,
    :logs_bloom,
    :root,
    :status,
    :to,
    :transaction_hash,
    :transaction_index,
    :type,
    raw: %{}
  ]

  @typedoc """
  A transaction receipt with the following fields (`nil` when the node omits the member):

  - `transaction_hash` - hash of the transaction.
  - `transaction_index` - index of the transaction in its block.
  - `block_hash` - hash of the block including the transaction.
  - `block_number` - number of the block including the transaction.
  - `from` - checksummed address of the sender.
  - `to` - checksummed address of the receiver, `nil` for a contract creation transaction.
  - `contract_address` - checksummed address of the contract created by the transaction,
    `nil` if it is not a contract creation transaction.
  - `type` - the [EIP-2718](https://eips.ethereum.org/EIPS/eip-2718) type id of the
    transaction as an integer (e.g. `2` for EIP-1559), including types the library has no
    transaction module for (e.g. `126` for OP Stack deposit transactions). Compare it with
    the `type_id/0` of a transaction module, e.g. `Ethers.Transaction.Eip1559.type_id()`.
  - `status` - `:success` or `:failure`. `nil` for transactions included before the
    Byzantium upgrade, whose receipts hold `root` instead.
  - `root` - the post-transaction state root, only present in receipts of transactions
    included before the Byzantium upgrade.
  - `gas_used` - gas used by this transaction alone.
  - `cumulative_gas_used` - sum of the gas used by this transaction and all preceding
    transactions in the same block.
  - `effective_gas_price` - the actual price per gas paid by the sender in wei.
  - `blob_gas_used` - blob gas used by the transaction, only present for blob
    ([EIP-4844](https://eips.ethereum.org/EIPS/eip-4844)) transactions.
  - `blob_gas_price` - the actual price per blob gas paid by the sender in wei, only present
    for blob transactions.
  - `logs` - the logs emitted by the transaction, as returned by the node.
  - `logs_bloom` - the 256 byte bloom filter of the logs, as a binary.
  - `raw` - the receipt exactly as returned by the node, including chain specific members.
  """
  @type t :: %__MODULE__{
          blob_gas_price: non_neg_integer() | nil,
          blob_gas_used: non_neg_integer() | nil,
          block_hash: Types.t_hash() | nil,
          block_number: non_neg_integer() | nil,
          contract_address: Types.t_address() | nil,
          cumulative_gas_used: non_neg_integer() | nil,
          effective_gas_price: non_neg_integer() | nil,
          from: Types.t_address() | nil,
          gas_used: non_neg_integer() | nil,
          logs: [map()] | nil,
          logs_bloom: binary() | nil,
          raw: map(),
          root: Types.t_hash() | nil,
          status: :success | :failure | nil,
          to: Types.t_address() | nil,
          transaction_hash: Types.t_hash() | nil,
          transaction_index: non_neg_integer() | nil,
          type: non_neg_integer() | nil
        }

  # Struct field => {RPC member, decoder}
  @members [
    transaction_hash: {"transactionHash", :hash},
    transaction_index: {"transactionIndex", :quantity},
    block_hash: {"blockHash", :hash},
    block_number: {"blockNumber", :quantity},
    from: {"from", :address},
    to: {"to", :address},
    contract_address: {"contractAddress", :address},
    type: {"type", :quantity},
    status: {"status", :status},
    root: {"root", :hash},
    gas_used: {"gasUsed", :quantity},
    cumulative_gas_used: {"cumulativeGasUsed", :quantity},
    effective_gas_price: {"effectiveGasPrice", :quantity},
    blob_gas_used: {"blobGasUsed", :quantity},
    blob_gas_price: {"blobGasPrice", :quantity},
    logs: {"logs", :logs},
    logs_bloom: {"logsBloom", :bytes}
  ]

  @doc false
  @spec from_rpc_map(term()) ::
          {:ok, t()} | {:error, :invalid_receipt | {:invalid_receipt_member, String.t()}}
  def from_rpc_map(receipt) when is_map(receipt) do
    Enum.reduce_while(@members, {:ok, %__MODULE__{raw: receipt}}, fn
      {field, {member, kind}}, {:ok, decoded} ->
        case receipt |> Map.get(member) |> decode_member(kind) do
          {:ok, value} -> {:cont, {:ok, Map.put(decoded, field, value)}}
          :error -> {:halt, {:error, {:invalid_receipt_member, member}}}
        end
    end)
  end

  def from_rpc_map(_receipt), do: {:error, :invalid_receipt}

  defp decode_member(nil, _kind), do: {:ok, nil}

  defp decode_member("0x" <> hex = hash, :hash) when byte_size(hex) == 64 do
    case Utils.hex_decode(hex) do
      {:ok, _hash_bin} -> {:ok, hash}
      :error -> :error
    end
  end

  defp decode_member("0x" <> _ = quantity, :quantity) do
    case Utils.hex_to_integer(quantity) do
      {:ok, integer} -> {:ok, integer}
      {:error, _reason} -> :error
    end
  end

  defp decode_member(address, :address) do
    case Utils.decode_address(address) do
      {:ok, address_bin} -> {:ok, Utils.encode_address!(address_bin)}
      _invalid -> :error
    end
  end

  defp decode_member(status, :status) do
    case decode_member(status, :quantity) do
      {:ok, 1} -> {:ok, :success}
      {:ok, 0} -> {:ok, :failure}
      _invalid -> :error
    end
  end

  defp decode_member("0x" <> hex, :bytes) do
    case Utils.hex_decode(hex) do
      {:ok, bytes} -> {:ok, bytes}
      :error -> :error
    end
  end

  defp decode_member(logs, :logs) when is_list(logs) do
    if Enum.all?(logs, &is_map/1), do: {:ok, logs}, else: :error
  end

  defp decode_member(_value, _kind), do: :error
end
