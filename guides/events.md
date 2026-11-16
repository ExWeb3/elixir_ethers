# Events

Contracts emit events as logs. This guide covers building filters for them, fetching the logs, and
reading the result.

The examples use a contract module named `MyToken`, generated from an ERC-20 ABI with a default
address (see [Contracts](contracts.md)), and this value:

```elixir
holder = "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045"
```

## Event filters

Each contract module has an `EventFilters` module with one function per event. The arguments of the
function are the indexed arguments of the event. Pass a value to match it, or `nil` to match
anything.

```elixir
# Transfers from anyone to `holder`
filter = MyToken.EventFilters.transfer(nil, holder)
```

Like contract functions, a filter is a value that describes a query. In IEx it prints as the event
signature with your arguments filled in:

```elixir
iex> MyToken.EventFilters.transfer(nil, holder)
#Ethers.EventFilter<
  event Transfer(
    address indexed from any,
    address indexed to "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045",
    uint256 value
  )
  default_address: "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"
>
```

The filter functions are documented like the contract functions: try
`h MyToken.EventFilters.transfer` in IEx.

## Fetching logs

`Ethers.get_logs/2` runs a filter and returns the matching events.

```elixir
filter = MyToken.EventFilters.transfer(nil, nil)

{:ok, events} = Ethers.get_logs(filter, from_block: 26_425_607, to_block: 26_425_607)
```

Options:

- `:from_block` and `:to_block` - the block range to search.
- `:address` - the contract that emitted the events. Defaults to the default address of the
  contract module. Without either, logs of every contract are matched.
- `:rpc_opts` - options for the RPC client.

> #### Bound the block range {: .tip}
>
> Most providers limit how many blocks or results one request may cover. Fetch large histories in
> chunks of blocks.

## The event struct

Each result is an `Ethers.Event` struct:

```elixir
%Ethers.Event{
  address: "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2",
  topics: [
    "Transfer(address,address,uint256)",
    "0x000000000004444c5dc75cB358380D2e3dE08A90",
    "0x0000000aa232009084Bd71A5797d089AA4Edfad4"
  ],
  data: [18310393930514111],
  block_number: 26425607,
  block_hash: "0x689371fca9da4fe412553a094b5360a9077ea1d078203eee9efd9a4ccdb6df00",
  transaction_hash: "0xdea835593a1eb84c0a95085ab363a204a804407c5d27c26b8ab083cda7d132d7",
  transaction_index: 0,
  log_index: 1,
  removed: false,
  topics_raw: [...],
  data_raw: "0x00000000000000000000000000000000000000000000000000410d34cdecfebf"
}
```

- `topics` holds the event signature followed by the decoded indexed arguments.
- `data` holds the decoded non-indexed arguments, in order.
- `address` is the contract that emitted the event, checksummed.
- `topics_raw` and `data_raw` hold the values as the node returned them.

For the `Transfer` event above, the sender and the receiver are indexed and the amount is not:

```elixir
%Ethers.Event{topics: [_signature, from, to], data: [amount]} = event
```

## Several events at once

`Ethers.EventFilter.combine/1` merges filters into one request. A log matches when it matches any
of them.

```elixir
filter =
  Ethers.EventFilter.combine([
    MyToken.EventFilters.transfer(nil, nil),
    MyToken.EventFilters.approval(nil, nil)
  ])

{:ok, events} = Ethers.get_logs(filter, from_block: 26_425_607)
```

To match every event of a contract, pass its `EventFilters` module:

```elixir
{:ok, events} = Ethers.get_logs(MyToken.EventFilters, from_block: 26_425_607)
```

Tell the events apart by the signature in `topics`:

```elixir
Enum.map(events, fn
  %Ethers.Event{topics: ["Transfer(address,address,uint256)", from, to]} -> {:transfer, from, to}
  %Ethers.Event{topics: ["Approval(address,address,uint256)", owner, _]} -> {:approval, owner}
end)
```

## Events of a transaction

A receipt holds the logs of every contract the transaction called. `Ethers.Receipt.decode_logs/2`
decodes the ones that match a filter, a combined filter or an `EventFilters` module, and skips the
rest.

```elixir
{:ok, receipt} =
  Ethers.get_transaction_receipt(
    "0xdea835593a1eb84c0a95085ab363a204a804407c5d27c26b8ab083cda7d132d7"
  )

length(receipt.logs)
#=> 7

receipt |> Ethers.Receipt.decode_logs(Ethers.Contracts.ERC20.EventFilters) |> length()
#=> 5
```

## Built-in contracts

The built-in token interfaces such as `Ethers.Contracts.ERC20` have no default address, so pass
`:address` to select the contract:

```elixir
weth = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"

Ethers.Contracts.ERC20.EventFilters.transfer(nil, holder)
|> Ethers.get_logs(address: weth, from_block: 26_425_000)
```

## Native ETH transfer logs (EIP-7708)

On networks with [EIP-7708](https://eips.ethereum.org/EIPS/eip-7708) active (the Glamsterdam
upgrade), every ETH transfer with a non-zero value emits a log from
`0xfffffffffffffffffffffffffffffffffffffffe` that has the same topics and data as an ERC-20
`Transfer` event. A `Transfer` filter without an address returns these logs too, decoded as token
transfers. Filter by the token address, or tell them apart with `Ethers.Event.eth_transfer_log?/1`:

```elixir
{:ok, events} = Ethers.get_logs(Ethers.Contracts.ERC20.EventFilters.transfer(nil, nil))

token_transfers = Enum.reject(events, &Ethers.Event.eth_transfer_log?/1)
```
