<!-- Machine-readable documentation index for LLMs and coding agents: https://ethers.hexdocs.pm/llms.txt (every docs page is also available as Markdown by replacing .html with .md). Rules for coding agents using this library: usage-rules.md -->

<img height="144" align="left" src="https://github.com/ExWeb3/elixir_ethers/raw/main/assets/ethers_logo.png" alt="Elixir Ethers logo">

<!-- GitHub draws no underline for a heading inside <summary>, and type="none" hides the list marker -->
<ul type="none"><summary><h1>Elixir Ethers</h1></summary></ul>

[![Hex.pm](https://img.shields.io/hexpm/v/ethers.svg)](https://hex.pm/packages/ethers)
[![Docs](https://img.shields.io/badge/docs-hexdocs-8e44ad.svg)](https://ethers.hexdocs.pm)
[![CI](https://img.shields.io/github/actions/workflow/status/ExWeb3/elixir_ethers/elixir.yml?branch=main&label=CI)](https://github.com/ExWeb3/elixir_ethers/actions/workflows/elixir.yml)
[![Coverage](https://img.shields.io/coverallsCoverage/github/ExWeb3/elixir_ethers?branch=main)](https://coveralls.io/github/ExWeb3/elixir_ethers?branch=main)
[![Downloads](https://img.shields.io/hexpm/dt/ethers.svg)](https://hex.pm/packages/ethers)
[![License](https://img.shields.io/hexpm/l/ethers.svg)](https://github.com/ExWeb3/elixir_ethers/blob/main/LICENSE)

**Smart contracts as plain Elixir functions.** Ethers turns a contract ABI into a documented Elixir
module at compile time, then takes care of the rest: sending transactions, reading events, signing
and verifying messages, and resolving ENS names, on Ethereum or any other EVM chain.

```elixir
defmodule MyToken do
  use Ethers.Contract,
    abi_file: "priv/abi/my_token.json",
    default_address: "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"
end

# Read
MyToken.balance_of(holder) |> Ethers.call()
#=> {:ok, 1468927766030343079}

# Write
MyToken.transfer(recipient, 1000) |> Ethers.send_transaction(from: sender)
#=> {:ok, "0x873d06f7...794c0f4c"}

# Events
MyToken.EventFilters.transfer(nil, holder) |> Ethers.get_logs()
#=> {:ok, [%Ethers.Event{...}]}
```

## Installation

Add `ethers` to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ethers, "~> 1.0"},
    # Optional: only needed to sign with a local private key
    {:ex_secp256k1, "~> 0.7"}
  ]
end
```

Then point it at a JSON-RPC endpoint: your own node, a provider, or a public endpoint from
[chainlist.org](https://chainlist.org/).

```elixir
# config/config.exs
config :ethereumex, url: "https://your-ethereum-node.example"
```

Ethers needs Elixir 1.18 or later. Coming from 0.8 or earlier? Read the
[upgrade guide](https://ethers.hexdocs.pm/upgrading.html).

## Try it

Paste this into a plain `iex` session. It needs nothing but Elixir, and reads from Ethereum mainnet
through a public endpoint.

```elixir
Mix.install([{:ethers, "~> 1.0"}],
  config: [ethereumex: [url: "https://ethereum-rpc.publicnode.com"]]
)

alias Ethers.Contracts.ERC20

weth = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"

ERC20.symbol() |> Ethers.call!(to: weth)
#=> "WETH"

vitalik = Ethers.NameService.resolve!("vitalik.eth")
#=> "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045"

ERC20.balance_of(vitalik) |> Ethers.call!(to: weth) |> Ethers.Utils.from_wei()
#=> 1.4689277660303433
```

Prefer a notebook? The interactive tour covers contracts, events, fees and signing.

[![Run in Livebook](https://livebook.dev/badge/v1/blue.svg)](https://livebook.dev/run?url=https%3A%2F%2Fgithub.com%2FExWeb3%2Felixir_ethers%2Fblob%2Fmain%2Fguides%2Ftour.livemd)

## How it works

Contract functions never touch the network. They return an `Ethers.TxData` struct that describes
the call, and you choose what happens to it:

```elixir
transfer = MyToken.transfer(recipient, 1000)

Ethers.call(transfer, from: sender)              # run it without sending
Ethers.estimate_gas(transfer, from: sender)      # ask what it would cost
Ethers.send_transaction(transfer, from: sender)  # sign and broadcast it
```

The same value goes into `Ethers.Multicall` to bundle many reads into one call, or into
`Ethers.batch/2` to bundle JSON-RPC requests. Event filters follow the same pattern:
`MyToken.EventFilters.transfer(nil, holder)` builds a filter and `Ethers.get_logs/2` runs it.

Results come back as Elixir values: integers instead of hex strings, checksummed addresses,
decoded events and receipts, and structs for a contract's custom errors.

> [!IMPORTANT]
> `Ethers.send_transaction/2` needs something to sign with. Public RPC endpoints do not hold your
> keys, so set up a [signer](https://ethers.hexdocs.pm/signing.html) first.

## What's included

- **Contracts.** Modules generated from any ABI, with docs and typespecs. Built-in ERC-20, ERC-721,
  ERC-1155, ERC-777 and ERC-165 interfaces. Typed event filters and decoded logs, custom errors as
  structs, deployment, Multicall3 and JSON-RPC batching.
  [Contracts](https://ethers.hexdocs.pm/contracts.html) ·
  [Events](https://ethers.hexdocs.pm/events.html)
- **Transactions.** Legacy, EIP-2930, EIP-1559 and EIP-7702 transactions, and EIP-4844 without blob
  sidecars. Fee estimation from recent blocks, access lists, decoded receipts, and simulation
  against overridden chain state.
  [Transactions](https://ethers.hexdocs.pm/transactions.html)
- **Signing.** Pluggable signers: a local key, a JSON-RPC signer, or your own. EIP-191 messages and
  EIP-712 typed data, signature verification that also works for smart-contract wallets (ERC-1271,
  ERC-6492), and Sign-In with Ethereum.
  [Signing](https://ethers.hexdocs.pm/signing.html) ·
  [EIP-712](https://ethers.hexdocs.pm/eip-712.html) ·
  [SIWE](https://ethers.hexdocs.pm/siwe.html)
- **Network.** Any EVM chain that speaks JSON-RPC. ENS resolution with CCIP-Read, and a replaceable
  RPC client. [Configuration](https://ethers.hexdocs.pm/configuration.html)

## Documentation

- [Getting started](https://ethers.hexdocs.pm/getting-started.html), from an empty project to a
  first transaction
- [Cheatsheet](https://ethers.hexdocs.pm/cheatsheet.html), the common operations on one page
- [API reference](https://ethers.hexdocs.pm/api-reference.html),
  [changelog](https://ethers.hexdocs.pm/changelog.html) and
  [upgrade guide](https://ethers.hexdocs.pm/upgrading.html)
- For LLMs and coding agents: [llms.txt](https://ethers.hexdocs.pm/llms.txt) indexes every page,
  any docs page is available as Markdown by replacing `.html` with `.md`, and the package ships a
  [`usage-rules.md`](https://github.com/ExWeb3/elixir_ethers/blob/main/usage-rules.md)

## Contributing

Contributions are welcome, from typo fixes to new features. See
[CONTRIBUTING.md](https://github.com/ExWeb3/elixir_ethers/blob/main/CONTRIBUTING.md) for the
development setup. To report a vulnerability, follow the
[security policy](https://github.com/ExWeb3/elixir_ethers/blob/main/SECURITY.md).

## Acknowledgements

Ethers was possible to make thanks to the great contributors of
[ABI](https://github.com/poanetwork/ex_abi),
[Ethereumex](https://github.com/mana-ethereum/ethereumex) and
[ExKeccak](https://github.com/tzumby/ex_keccak), and to everyone who contributed to this project.

## License

[Apache License 2.0](https://github.com/ExWeb3/elixir_ethers/blob/main/LICENSE)
