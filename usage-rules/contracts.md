# Contracts

- `Ethers.call/2` executes a contract function with `eth_call` and decodes the result. It returns
  `{:ok, value}` for one return value, `{:ok, [value1, value2]}` for several, and `{:ok, nil}` for
  a function that returns nothing.
- `Ethers.call/2` also works for state-changing functions. Nothing is sent, so use it to check what
  a transaction would return or whether it would revert, with `from: account` to set the caller.
- Options of `Ethers.call/2`: `:to` (required without a default address), `:from`, `:value` (wei),
  `:block` (a number or a tag such as `"latest"`), `:state_overrides` and `:rpc_opts`.
- Without `:to` and without a default address the result is `{:error, :no_to_address}`.

```elixir
defmodule MyApp.Token do
  use Ethers.Contract,
    abi_file: "priv/abi/token.json",
    default_address: "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"
end

{:ok, balance} = MyApp.Token.balance_of(holder) |> Ethers.call()
{:ok, symbol} = Ethers.Contracts.ERC20.symbol() |> Ethers.call(to: token_address)
```

## Errors

- A revert with a custom error declared in the ABI is returned by `Ethers.call/2` as
  `{:error, %MyContract.Errors.ErrorName{}}`, with the error arguments as struct fields. Match on
  the struct.
- A revert with a plain message (`require`, `revert("...")`) is returned as the error map of the
  node, such as `{:error, %{"code" => 3, "message" => "execution reverted: ...", "data" => "0x..."}}`.
- `Ethers.call!/2` raises `Ethers.ExecutionError` in both cases.

## Overloaded functions

- When a contract overloads a function with the same number of arguments, wrap the ambiguous
  arguments with `Ethers.Types.typed/2`, for example `Ethers.Types.typed({:uint, 256}, 100)`.

## Many calls

- To read several values from the same block in one request, use `Ethers.Multicall.aggregate3/1`,
  then `Ethers.call/2`, then `Ethers.Multicall.decode/2`. Each decoded result is a
  `{success?, value}` tuple.
- To send several independent JSON-RPC requests in one round trip, use `Ethers.batch/2`. Its
  results are not guaranteed to come from the same block.

```elixir
calls = [MyApp.Token.symbol(), MyApp.Token.decimals()]

calls
|> Ethers.Multicall.aggregate3()
|> Ethers.call!()
|> Ethers.Multicall.decode(calls)
#=> [true: "WETH", true: 18]
```

## Simulation

- To run a call against modified chain state, pass `:state_overrides` to `Ethers.call/2` or
  `Ethers.estimate_gas/2`. See `Ethers.StateOverride` for the structure. Balances and nonces are
  integers and code is a raw binary. State overrides are not supported in `Ethers.batch/2`.

## Deployment

- Deploy with `Ethers.deploy/2`. It needs a contract module whose ABI file contains the bytecode
  under the `"bin"` key, or the bytecode as a hex string. Encode constructor arguments with the
  generated `constructor` function and pass them as `:encoded_constructor`.
- `Ethers.deploy/2` returns the transaction hash. Get the address with
  `Ethers.deployed_address/2` once the transaction is included in a block.

## Names

- Resolve ENS names with `Ethers.NameService.resolve/2` and addresses with
  `Ethers.NameService.reverse_resolve/2`.
