# Contracts

A contract module is an Elixir module generated from a contract ABI at compile time. This guide
covers defining one, calling its functions, and what comes back.

The examples use these values:

```elixir
holder = "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045"
sender = "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
recipient = "0x70997970C51812dc3A010C7d01b50e0d17dc79C8"
weth = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"
```

## Defining a contract module

```elixir
defmodule MyToken do
  use Ethers.Contract,
    abi_file: "priv/abi/my_token.json",
    default_address: "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"
end
```

`Ethers.Contract` accepts these options:

- `:abi_file` - path to the ABI as JSON. The file holds either the ABI array itself or a compiler
  output object with an `"abi"` key (and optionally `"bin"`, the bytecode used for
  [deployment](#deploying-a-contract)).
- `:abi` - the ABI itself, as a decoded list or as a JSON string, instead of a file.
- `:default_address` - the address calls go to when no `:to` is given. Optional.
- `:skip_docs` - skip generating docs and typespecs, for all functions or for a list of them.

The module gets one function for each contract function, named in snake case (`balanceOf` becomes
`balance_of/1`), plus an `EventFilters` module for its events and an `Errors` module for its custom
errors. All of them are documented: try `h MyToken.balance_of` in IEx, or build your project docs.

## Calling functions

Contract functions do not touch the network. They return an `Ethers.TxData` struct that describes
the call, and `Ethers.call/2` executes it with `eth_call`.

```elixir
MyToken.balance_of(holder) |> Ethers.call()
#=> {:ok, 1468927766030343079}

MyToken.balance_of(holder) |> Ethers.call!()
#=> 1468927766030343079
```

`Ethers.call/2` returns:

- `{:ok, value}` for a function with one return value
- `{:ok, [value1, value2]}` for a function with several
- `{:ok, nil}` for a function that returns nothing
- `{:error, reason}` when the call fails, see [Errors](#errors)

Useful options:

- `:to` - the contract address. Required when the module has no default address.
- `:from` - the account the call is made as (`msg.sender`).
- `:value` - ether sent along with the call, in wei.
- `:block` - a block number or a tag such as `"latest"` or `"finalized"`.
- `:rpc_opts` - options for the RPC client, such as `[url: "https://..."]`.

`Ethers.call/2` works for any function, including state-changing ones. Nothing is sent, so it is a
cheap way to check what a transaction would return or whether it would revert:

```elixir
MyToken.transfer(recipient, 1000) |> Ethers.call(from: holder)
#=> {:ok, true}
```

### Inspecting a call

In IEx, a `Ethers.TxData` prints as the function signature with your arguments filled in:

```elixir
iex> MyToken.balance_of(holder)
#Ethers.TxData<
  function balanceOf(
    address account "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045"
  ) view returns (
    uint256
  )
  default_address: "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"
>
```

## Argument and return types

| Solidity | Elixir |
| --- | --- |
| `address` | `"0x..."` hex string. Accepted in any casing, returned EIP-55 checksummed |
| `uint*`, `int*` | integer |
| `bool` | boolean |
| `string` | string |
| `bytes`, `bytes1` to `bytes32` | raw binary, not a hex string |
| `T[]`, `T[n]` | list |
| tuples and structs | tuple |

> #### Bytes are binaries {: .warning}
>
> A `bytes` argument given as `"0x80ac58cd"` is not decoded for you. Convert hex strings with
> `Ethers.Utils.hex_decode!/1` first.

```elixir
interface_id = Ethers.Utils.hex_decode!("0x80ac58cd")

Ethers.Contracts.ERC165.supports_interface(interface_id)
|> Ethers.call(to: "0xBC4CA0EdA7647A8aB7C2061c2E118A18a936f13D")
#=> {:ok, true}
```

Amounts are integers in the smallest unit. `Ethers.Utils.to_wei/1` and `Ethers.Utils.from_wei/1`
convert between ether and wei.

When a contract overloads a function with the same number of arguments, Ethers cannot tell the
variants apart from Elixir values alone. See the [typed arguments guide](typed-arguments.md).

## Many calls at once

There are two ways to combine calls, and they are not the same thing.

`Ethers.Multicall` aggregates contract calls into a single `eth_call` through the
[Multicall3](https://www.multicall3.com/) contract. All results come from the same block.

```elixir
alias Ethers.Contracts.ERC20

calls = [
  {ERC20.symbol(), to: weth},
  {ERC20.decimals(), to: weth},
  {ERC20.balance_of(holder), to: weth}
]

calls
|> Ethers.Multicall.aggregate3()
|> Ethers.call!()
|> Ethers.Multicall.decode(calls)
#=> [true: "WETH", true: 18, true: 1468927766030343079]
```

Each result is a `{success?, value}` tuple. Calls from a module with a default address can be
listed without the `to:` tuple.

`Ethers.batch/2` sends several JSON-RPC requests in one HTTP round trip. The requests are
independent, can be of different kinds, and are not guaranteed to run on the same block.

```elixir
Ethers.batch([
  {:call, ERC20.symbol(), to: weth},
  {:get_balance, holder},
  :current_block_number
])
#=> {:ok, [ok: "WETH", ok: 5798969845714110716, ok: 26425798]}
```

## Built-in contracts

These interfaces ship with Ethers under `Ethers.Contracts`:

- `Ethers.Contracts.ERC20` - fungible tokens
- `Ethers.Contracts.ERC721` - non-fungible tokens (NFTs)
- `Ethers.Contracts.ERC1155` - multi-token standard
- `Ethers.Contracts.ERC777` - fungible tokens with hooks
- `Ethers.Contracts.ERC165` - interface detection
- `Ethers.Contracts.Multicall3`, `Ethers.Contracts.ENS`, `Ethers.Contracts.CcipRead` and
  `Ethers.Contracts.UniversalSigValidator` - used by `Ethers.Multicall`, `Ethers.NameService`,
  `Ethers.CcipRead` and `Ethers.Signature`

The token interfaces have no default address, so pass the contract address as `to:`.

## Errors

Functions that reach the network return `{:error, reason}` on failure. Their `!` variants, such as
`Ethers.call!/2`, raise `Ethers.ExecutionError` instead.

When a call reverts with a custom error declared in the ABI, `Ethers.call/2` decodes it into a
struct from the `Errors` module of the contract. The struct fields are the arguments of the error.
For a contract that declares `error InsufficientBalance(uint256 available, uint256 required)`:

```elixir
MyContract.withdraw(1000) |> Ethers.call(from: holder)
#=> {:error, %MyContract.Errors.InsufficientBalance{available: 0, required: 1000}}
```

A revert with a plain message, as produced by `require` and `revert("...")`, is returned as the
error map of the node:

```elixir
#=> {:error, %{"code" => 3, "message" => "execution reverted: not allowed", "data" => "0x..."}}
```

Some failures are caught before any request is made, for example `{:error, :no_to_address}` when
neither `:to` nor a default address is available.

## Simulating with state overrides

`Ethers.call/2` and `Ethers.estimate_gas/2` can run against a modified view of the chain: a
different balance or nonce, replaced contract code, or rewritten storage slots. Nothing is sent or
stored. Here an address gets a balance of 100 ether for the duration of one call:

```elixir
burn = "0x000000000000000000000000000000000000dEaD"

Ethers.Contracts.Multicall3.get_eth_balance(burn)
|> Ethers.call(state_overrides: %{burn => %{balance: Ethers.Utils.to_wei(100)}})
#=> {:ok, 100000000000000000000}
```

`Ethers.StateOverride` documents the accepted structure. State overrides are not available in
`Ethers.batch/2`.

## Deploying a contract

Deployment needs the bytecode of the contract. `Ethers.deploy/2` takes it from a contract module
whose ABI file includes the `"bin"` key, or as a hex string.

```elixir
{:ok, tx_hash} =
  Ethers.deploy(Counter,
    encoded_constructor: Counter.constructor(100),
    from: sender
  )
```

`constructor/n` is generated from the ABI and encodes the constructor arguments. Once the
transaction is included in a block, `Ethers.deployed_address/2` returns the address:

```elixir
{:ok, address} = Ethers.deployed_address(tx_hash)
#=> {:ok, "0x30752F78C627844aA52f49808202550E6485B050"}

Counter.get() |> Ethers.call(to: address)
#=> {:ok, 100}
```

`Ethers.deploy/2` accepts the same options as `Ethers.send_transaction/2`. See the
[transactions guide](transactions.md).

## ENS names

`Ethers.NameService` resolves [ENS](https://ens.domains/) names, and names of ENS-compatible
services, in both directions.

```elixir
Ethers.NameService.resolve("vitalik.eth")
#=> {:ok, "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045"}

Ethers.NameService.reverse_resolve("0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045")
#=> {:ok, "vitalik.eth"}
```
