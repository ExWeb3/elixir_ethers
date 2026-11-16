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
  - Members this version of the library does not decode, such as chain specific members
    (e.g. the L1 fee members of OP Stack chains) or node extras, are kept undecoded in
    `extra`.

  `Ethers.get_transaction_receipt/2` returns `{:error, {:invalid_receipt_member, member}}`
  when the node returns a member that does not match the schema (e.g. a `status` other than
  `"0x0"` or `"0x1"`), with `member` the RPC member name (e.g. `"status"`).

  ## Logs

  A receipt holds the logs of every contract the transaction called, and decoding a log
  requires the ABI of its event. The logs are therefore kept as returned by the node (maps
  with string keys, the form `Ethers.Event.decode/2` and `Ethers.Event.find_and_decode/2`
  accept). Use `decode_logs/2` to decode the logs matching an event filter, a combined event
  filter or all events of a contract into `Ethers.Event` structs.

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
        extra: %{},
        ...
      }

      Ethers.Receipt.decode_logs(receipt, Ethers.Contracts.ERC20.EventFilters)
      #=> [%Ethers.Event{topics: ["Transfer(address,address,uint256)", ...], ...}]
  """

  alias Ethers.CombinedEventFilter
  alias Ethers.ContractHelpers
  alias Ethers.Event
  alias Ethers.EventFilter
  alias Ethers.Types
  alias Ethers.Utils

  import Ethers.Types, only: [is_module: 1]

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
    extra: %{}
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
  - `blob_gas_price` - the actual price per blob gas paid by the sender in wei. Specified for
    blob transactions only, but some nodes (e.g. anvil) return it for every transaction.
  - `logs` - the logs emitted by the transaction, as returned by the node. See
    `decode_logs/2`.
  - `logs_bloom` - the 256 byte bloom filter of the logs, as a binary.
  - `extra` - the members returned by the node that this version of the library does not
    decode (e.g. the L1 fee members of OP Stack chains), with their RPC member names as keys
    and their values as returned by the node. `%{}` when there are none. It only holds
    members this version does not decode, so a member can move from `extra` to a struct
    field in a later release.
  """
  @type t :: %__MODULE__{
          blob_gas_price: non_neg_integer() | nil,
          blob_gas_used: non_neg_integer() | nil,
          block_hash: Types.t_hash() | nil,
          block_number: non_neg_integer() | nil,
          contract_address: Types.t_address() | nil,
          cumulative_gas_used: non_neg_integer() | nil,
          effective_gas_price: non_neg_integer() | nil,
          extra: %{optional(String.t()) => term()},
          from: Types.t_address() | nil,
          gas_used: non_neg_integer() | nil,
          logs: [map()] | nil,
          logs_bloom: binary() | nil,
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

  @known_members Enum.map(@members, fn {_field, {member, _kind}} -> member end)

  @doc false
  @spec from_rpc_map(term()) ::
          {:ok, t()} | {:error, :invalid_receipt | {:invalid_receipt_member, String.t()}}
  def from_rpc_map(receipt) when is_map(receipt) do
    extra = Map.drop(receipt, @known_members)

    Enum.reduce_while(@members, {:ok, %__MODULE__{extra: extra}}, fn
      {field, {member, kind}}, {:ok, decoded} ->
        case receipt |> Map.get(member) |> decode_member(kind) do
          {:ok, value} -> {:cont, {:ok, Map.put(decoded, field, value)}}
          :error -> {:halt, {:error, {:invalid_receipt_member, member}}}
        end
    end)
  end

  def from_rpc_map(_receipt), do: {:error, :invalid_receipt}

  @doc """
  Decodes the logs of the receipt matching the given filter into `Ethers.Event` structs, in
  the order they were emitted.

  The filter can be one of:

  - A single event filter. (e.g. `MyContract.EventFilters.transfer(nil, nil)`)
  - A combined event filter matching multiple events, created with
    `Ethers.EventFilter.combine/1`.
  - An EventFilters module of a contract (e.g. `MyContract.EventFilters`) to match all
    events of that contract.

  A log matches an event of the filter when:

  - its first topic is the event signature hash,
  - its other topics match the indexed argument values of the filter (`nil` matches any
    value) and their count matches the number of indexed arguments of the event,
  - it was emitted by the default address of the filter (if it has one), and
  - its data decodes as the non-indexed arguments of the event.

  Apart from the exact topic count and the data check, these are the rules `Ethers.get_logs/2`
  filters logs with. The two extra checks matter for receipts, which hold the logs of every
  contract the transaction called: events with the same signature can differ in which
  arguments are indexed (e.g. the ERC-20 and ERC-721 `Transfer` events), and any contract can
  emit a log with an event's signature but malformed data. Such logs are skipped instead of
  being decoded as the wrong event or raising, like all logs matching none of the events of
  the filter.

  ## Examples

      {:ok, receipt} = Ethers.get_transaction_receipt(tx_hash)

      # All events of a contract
      Ethers.Receipt.decode_logs(receipt, Ethers.Contracts.ERC20.EventFilters)
      #=> [%Ethers.Event{topics: ["Transfer(address,address,uint256)", from, to], ...}]

      # Only transfers to `to`
      Ethers.Receipt.decode_logs(receipt, Ethers.Contracts.ERC20.EventFilters.transfer(nil, to))
      #=> [%Ethers.Event{data: [amount], ...}]
  """
  @spec decode_logs(t(), EventFilter.t() | CombinedEventFilter.t() | module()) :: [Event.t()]
  def decode_logs(%__MODULE__{} = receipt, events_module) when is_module(events_module),
    do: decode_logs(receipt, CombinedEventFilter.all!(events_module))

  def decode_logs(%__MODULE__{logs: logs}, filter) do
    {address, events} = log_matchers(filter)

    Enum.flat_map(logs || [], &decode_log(&1, address, events))
  end

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

  # Returns the default address of the filter and its events as a map of lowercase topic_0
  # to the event selector and the filter of each indexed argument (nil matches any value)
  defp log_matchers(%EventFilter{topics: [topic_0 | sub_topics], selector: selector} = filter),
    do: {filter.default_address, %{String.downcase(topic_0) => {selector, sub_topics}}}

  defp log_matchers(%CombinedEventFilter{selectors: selectors} = filter) do
    events =
      Map.new(selectors, fn {topic_0, selector} ->
        wildcards = selector |> ContractHelpers.event_indexed_types() |> Enum.map(fn _ -> nil end)

        {topic_0, {selector, wildcards}}
      end)

    {filter.default_address, events}
  end

  defp decode_log(%{"topics" => [topic_0 | sub_topics]} = log, address, events)
       when is_binary(topic_0) do
    with true <- address_matches?(log, address),
         {:ok, {selector, sub_topic_filters}} <- Map.fetch(events, String.downcase(topic_0)),
         true <- sub_topics_match?(sub_topics, sub_topic_filters),
         {:ok, event} <- decode_event(log, selector) do
      [event]
    else
      _no_match -> []
    end
  end

  defp decode_log(_log, _address, _events), do: []

  defp address_matches?(_log, nil), do: true

  defp address_matches?(%{"address" => log_address}, address) when is_binary(log_address),
    do: String.downcase(log_address) == String.downcase(address)

  defp address_matches?(_log, _address), do: false

  # Unlike eth_getLogs, the topic count must be exact: events with the same signature but
  # different indexed arguments (e.g. ERC-20 and ERC-721 Transfer) differ in their topic count
  defp sub_topics_match?(sub_topics, filters) when length(sub_topics) == length(filters) do
    sub_topics
    |> Enum.zip(filters)
    |> Enum.all?(fn
      {_topic, nil} -> true
      {topic, filter} when is_binary(topic) -> String.downcase(topic) == String.downcase(filter)
      _mismatch -> false
    end)
  end

  defp sub_topics_match?(_sub_topics, _filters), do: false

  # Any contract can emit a log with the signature and topic count of an event but data that
  # does not ABI decode as its arguments, on which the decoder raises (MatchError on short
  # data, ArgumentError on invalid hex). Such a log is not an instance of the event.
  defp decode_event(log, selector) do
    {:ok, Event.decode(log, selector)}
  rescue
    _error in [ArgumentError, MatchError] -> :error
  end
end
