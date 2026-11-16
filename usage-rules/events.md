# Events

- Every contract module has an `EventFilters` module with one function per event, for example
  `MyApp.Token.EventFilters.transfer/2`. Its arguments are the indexed arguments of the event only.
  Pass a value to match it, or `nil` to match anything.
- A filter performs no I/O. Fetch the matching events with `Ethers.get_logs/2`.
- Options of `Ethers.get_logs/2`: `:from_block`, `:to_block`, `:address` and `:rpc_opts`. Always
  bound the block range. Providers limit how much one request may cover, so fetch long histories in
  chunks of blocks.
- `:address` defaults to the default address of the contract module. For built-in modules such as
  `Ethers.Contracts.ERC20` pass it explicitly. Without any address, logs of all contracts match.

```elixir
{:ok, events} =
  MyApp.Token.EventFilters.transfer(nil, holder)
  |> Ethers.get_logs(from_block: from_block, to_block: to_block)
```

## The event struct

- Results are `Ethers.Event` structs. `topics` is the event signature string followed by the
  decoded indexed arguments. `data` is the list of decoded non-indexed arguments. `address` is the
  contract that emitted the event.
- Do not decode `topics_raw` or `data_raw` by hand. Use `topics` and `data`.

```elixir
%Ethers.Event{topics: ["Transfer(address,address,uint256)", from, to], data: [amount]} = event
```

## Several events

- To fetch several events in one request, combine filters with `Ethers.EventFilter.combine/1`.
- To fetch every event of a contract, pass the `EventFilters` module itself to
  `Ethers.get_logs/2`.
- Tell events apart by the signature string at the head of `topics`.

## Receipts

- To decode the events a transaction emitted, pass its receipt and a filter, a combined filter or
  an `EventFilters` module to `Ethers.Receipt.decode_logs/2`. Logs that do not match are skipped.
