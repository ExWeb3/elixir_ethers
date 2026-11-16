# Getting Started

Ethers lets you work with Ethereum and other EVM chains from Elixir. You give it the ABI of a
contract and it generates an Elixir module at compile time, with one documented function for each
contract function and event. This guide goes from an empty project to reading a contract, sending a
transaction and fetching events.

## Installation

Add `ethers` to the dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ethers, "~> 1.0"},
    {:ex_secp256k1, "~> 0.7"}
  ]
end
```

> #### ex_secp256k1 is optional {: .info}
>
> It is needed for `Ethers.Signer.Local` and for recovering the signer of a message or a
> transaction locally. Leave it out if a node or a remote signer does all your signing.

Ethers needs Elixir 1.15 or later. If you are coming from 0.8 or earlier, read the
[upgrade guide](upgrading.md) first.

## Connect to a node

Ethers talks to a chain through a JSON-RPC endpoint. Use the URL of your own node or of a provider,
or pick a public endpoint from [chainlist.org](https://chainlist.org/).

```elixir
# config/config.exs
config :ethereumex, url: "https://your-ethereum-node.example"
```

Check the connection from `iex -S mix`:

```elixir
Ethers.current_block_number()
#=> {:ok, 26425798}
```

Every function that reaches the network also accepts `rpc_opts: [url: "https://..."]`, which is
how one application talks to several chains. The [configuration guide](configuration.md) has the
details.

## Call a contract

Ethers ships with the interfaces of the common token standards, so you can read from any ERC-20
token without an ABI. This is WETH on Ethereum mainnet:

```elixir
alias Ethers.Contracts.ERC20

weth = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"
holder = "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045"

ERC20.symbol() |> Ethers.call(to: weth)
#=> {:ok, "WETH"}

ERC20.balance_of(holder) |> Ethers.call(to: weth)
#=> {:ok, 1468927766030343079}
```

`ERC20.balance_of(holder)` does not touch the network. It returns an `Ethers.TxData` struct that
describes the call, and `Ethers.call/2` executes it. The result is already decoded: token amounts
are integers in the smallest unit of the token, and `Ethers.Utils.from_wei/1` converts an 18-decimal
amount to a float for display.

## Generate a module for your own contract

For any other contract you need its ABI as JSON. Your compiler produces it, and block explorers such
as [etherscan.io](https://etherscan.io) publish it for verified contracts. Save it in your project
and point `Ethers.Contract` at it:

```elixir
defmodule MyToken do
  use Ethers.Contract,
    abi_file: "priv/abi/my_token.json",
    default_address: "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"
end
```

`default_address` is optional. With it, calls go to that address unless you pass `to:`.

Every function and event of the ABI is now an Elixir function, named in snake case, with docs and
typespecs. Try `h MyToken.balance_of` in IEx.

```elixir
MyToken.balance_of(holder) |> Ethers.call()
#=> {:ok, 1468927766030343079}
```

The [contracts guide](contracts.md) covers argument types, return values, errors, batching and
deployment.

## Send a transaction

Sending needs an account that can sign. The simplest setup for development is a private key held in
an environment variable:

```elixir
# config/runtime.exs
config :ethers,
  default_signer: Ethers.Signer.Local,
  default_signer_opts: [private_key: System.fetch_env!("ETH_PRIVATE_KEY")]
```

Then pipe a contract function into `Ethers.send_transaction/2`. The `:from` option is required.

```elixir
sender = "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
recipient = "0x70997970C51812dc3A010C7d01b50e0d17dc79C8"

{:ok, tx_hash} =
  MyToken.transfer(recipient, 1000) |> Ethers.send_transaction(from: sender)
```

The hash is returned as soon as the node accepts the transaction. Once it is included in a block,
its receipt is available:

```elixir
{:ok, receipt} = Ethers.get_transaction_receipt(tx_hash)

receipt.status
#=> :success
```

> #### Private keys {: .warning}
>
> Keep private keys out of source control and out of compile-time configuration. In production,
> prefer a signer that keeps the key outside your application. See [Signers](signing.md#signers).

The [transactions guide](transactions.md) covers fees, receipts and transaction types.

## Fetch events

Each contract module has an `EventFilters` module with one function per event. Pass `nil` for the
indexed arguments you do not want to filter on.

```elixir
filter = MyToken.EventFilters.transfer(nil, holder)

{:ok, events} = Ethers.get_logs(filter, from_block: 26_425_000)
```

The [events guide](events.md) describes the returned `Ethers.Event` structs and the other ways to
fetch logs.

## Where to go next

- [Interactive tour](tour.livemd): the same ground and more, in a notebook you can run
- [Cheatsheet](cheatsheet.cheatmd): the common operations on one page
- [Contracts](contracts.md), [Transactions](transactions.md), [Events](events.md) and
  [Signing and verification](signing.md)
- [Configuration](configuration.md): RPC endpoints, HTTP options, default signer and gas margins
