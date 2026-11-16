<!-- Machine-readable documentation index for LLMs and coding agents: https://ethers.hexdocs.pm/llms.txt (every docs page is also available as Markdown by replacing .html with .md) -->

<img height="144" align="left" src="https://github.com/ExWeb3/elixir_ethers/raw/main/assets/ethers_logo.png" alt="Elixir Ethers logo">

<!-- GitHub draws no underline for a heading inside <summary>, and type="none" hides the list marker -->
<ul type="none"><summary><h1>Elixir Ethers</h1></summary></ul>

[![CI](https://github.com/ExWeb3/elixir_ethers/actions/workflows/elixir.yml/badge.svg)](https://github.com/ExWeb3/elixir_ethers/actions/workflows/elixir.yml)
[![Coverage Status](https://coveralls.io/repos/github/ExWeb3/elixir_ethers/badge.svg?branch=main)](https://coveralls.io/github/ExWeb3/elixir_ethers?branch=main)
[![Module Version](https://img.shields.io/hexpm/v/ethers.svg)](https://hex.pm/packages/ethers)
[![Hex Docs](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://ethers.hexdocs.pm)
[![License](https://img.shields.io/hexpm/l/ethers.svg)](https://github.com/ExWeb3/elixir_ethers/blob/main/LICENSE)

Ethers is a Web3 library for Elixir for interacting with smart contracts on Ethereum and other
EVM-based blockchains. It turns a contract ABI into a documented Elixir module at compile time, so
calling a contract looks like calling any other Elixir function.

```elixir
alias Ethers.Contracts.ERC20

weth = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"

ERC20.symbol() |> Ethers.call(to: weth)
#=> {:ok, "WETH"}

ERC20.balance_of("0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045") |> Ethers.call(to: weth)
#=> {:ok, 1468927766030343079}
```

[Installation](#installation) · [Quick start](#quick-start) · [Usage](#usage) · [Signing](#signing) · [Features](#features) · [Documentation](#documentation)

## Installation

Add `ethers` to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ethers, "~> 1.0"},
    {:ex_secp256k1, "~> 0.7"}
  ]
end
```

> [!NOTE]
> `ex_secp256k1` is optional. It is needed for `Ethers.Signer.Local` and for recovering signers
> locally. Leave it out if a node or a remote signer does all your signing.

> [!TIP]
> Upgrading from 0.8 or earlier? The [upgrade guide](https://ethers.hexdocs.pm/upgrading.html)
> lists every breaking change.

## Quick start

**1. Configure a JSON-RPC endpoint.** Use the URL of your node or provider, or pick a public one
from [chainlist.org](https://chainlist.org/).

```elixir
# config/config.exs
config :ethereumex, url: "https://your-ethereum-node.example"
```

**2. Call a contract.** Ethers ships with the ERC-20 interface, so you can read from any token
right away. This is WETH on Ethereum mainnet:

```elixir
weth = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"

Ethers.Contracts.ERC20.symbol() |> Ethers.call(to: weth)
#=> {:ok, "WETH"}

Ethers.Contracts.ERC20.decimals() |> Ethers.call(to: weth)
#=> {:ok, 18}
```

**3. Generate a module for your own contract.** All you need is its ABI as JSON, from your
compiler or from a block explorer such as [etherscan.io](https://etherscan.io).

```elixir
defmodule MyToken do
  use Ethers.Contract,
    abi_file: "priv/abi/my_token.json",
    default_address: "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"
end
```

`default_address` is optional. Without it, pass `to: address` on each call.

Every function and event in the ABI is now an Elixir function with docs and typespecs. Try
`h MyToken.balance_of` in IEx. The rest of this page uses `MyToken` for a module like this one,
generated from an ERC-20 ABI.

## Usage

### Read contract state

Contract functions do not touch the network. They return an `Ethers.TxData` struct that describes
the call, and [`Ethers.call/2`](https://ethers.hexdocs.pm/Ethers.html#call/2) executes it.

```elixir
holder = "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045"

MyToken.balance_of(holder) |> Ethers.call()
#=> {:ok, 1468927766030343079}

MyToken.balance_of(holder) |> Ethers.call!()
#=> 1468927766030343079
```

A function with several return values gives `{:ok, [value1, value2]}`.

In IEx, the struct prints as a readable description of the call:

```text
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

> [!TIP]
> To make many calls in one round trip, use
> [`Ethers.Multicall`](https://ethers.hexdocs.pm/Ethers.Multicall.html) (one `eth_call` through the
> Multicall3 contract) or [`Ethers.batch/2`](https://ethers.hexdocs.pm/Ethers.html#batch/2) (one
> JSON-RPC batch request).

```elixir
Ethers.batch([
  {:call, MyToken.symbol()},
  {:get_balance, holder},
  :current_block_number
])
#=> {:ok, [ok: "WETH", ok: 5798969845714110716, ok: 26425608]}
```

If a contract has overloaded functions with the same number of arguments, see the
[typed arguments guide](https://ethers.hexdocs.pm/typed-arguments.html).

### Send transactions

Pipe the same kind of struct into
[`Ethers.send_transaction/2`](https://ethers.hexdocs.pm/Ethers.html#send_transaction/2) to get a
transaction hash back. `:from` is required.

```elixir
sender = "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
recipient = "0x70997970C51812dc3A010C7d01b50e0d17dc79C8"

{:ok, tx_hash} =
  MyToken.transfer(recipient, 1000)
  |> Ethers.send_transaction(
    from: sender,
    signer: Ethers.Signer.Local,
    signer_opts: [private_key: System.fetch_env!("ETH_PRIVATE_KEY")]
  )

#=> {:ok, "0x873d06f74640306bdde9f079536b8a6c70e12b6cbe1e30b71c391bd1794c0f4c"}
```

> [!IMPORTANT]
> Without a `:signer`, Ethers sends `eth_sendTransaction` and relies on the node to sign. Public
> RPC endpoints do not hold your keys, so they cannot do that. See [Signing](#signing).

Once the transaction is included in a block, its receipt is available:

```elixir
{:ok, receipt} = Ethers.get_transaction_receipt(tx_hash)

receipt.status
#=> :success

receipt.gas_used
#=> 28822
```

Other options include `:value` (in wei), `:gas`, `:nonce`, `:type` and the fee fields. Anything not
given is filled in from the network. See
[`Ethers.send_transaction/2`](https://ethers.hexdocs.pm/Ethers.html#send_transaction/2) for the
full list, and [`Ethers.deploy/2`](https://ethers.hexdocs.pm/Ethers.html#deploy/2) for deploying
contracts.

### Events

Each contract module has an `EventFilters` module with one function per event. Pass `nil` for an
indexed argument you do not want to filter on, then fetch the logs with
[`Ethers.get_logs/2`](https://ethers.hexdocs.pm/Ethers.html#get_logs/2).

```elixir
# Transfers from anyone to anyone. Use an address in place of `nil` to filter.
filter = MyToken.EventFilters.transfer(nil, nil)

{:ok, events} = Ethers.get_logs(filter, from_block: 26_425_607, to_block: 26_425_607)
```

Each event is an `Ethers.Event` struct. `topics` holds the event signature followed by the decoded
indexed arguments, and `data` holds the decoded non-indexed arguments:

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
  transaction_hash: "0xdea835593a1eb84c0a95085ab363a204a804407c5d27c26b8ab083cda7d132d7",
  log_index: 1,
  ...
}
```

Filters can be combined, and a whole contract can be used as a filter:

```elixir
# Several events in one request
filter =
  Ethers.EventFilter.combine([
    MyToken.EventFilters.transfer(nil, nil),
    MyToken.EventFilters.approval(nil, nil)
  ])

{:ok, events} = Ethers.get_logs(filter)

# Every event of a contract
{:ok, events} = Ethers.get_logs(MyToken.EventFilters)

# The events emitted by one transaction
events = Ethers.Receipt.decode_logs(receipt, MyToken.EventFilters)
```

### Built-in contracts

These interfaces ship with Ethers:

- [`ERC20`](https://ethers.hexdocs.pm/Ethers.Contracts.ERC20.html): fungible tokens
- [`ERC721`](https://ethers.hexdocs.pm/Ethers.Contracts.ERC721.html): non-fungible tokens (NFTs)
- [`ERC1155`](https://ethers.hexdocs.pm/Ethers.Contracts.ERC1155.html): multi-token standard
- [`ERC777`](https://ethers.hexdocs.pm/Ethers.Contracts.ERC777.html): fungible tokens with hooks
- [`ERC165`](https://ethers.hexdocs.pm/Ethers.Contracts.ERC165.html): interface detection
- [`Multicall3`](https://ethers.hexdocs.pm/Ethers.Contracts.Multicall3.html),
  [`ENS`](https://ethers.hexdocs.pm/Ethers.Contracts.ENS.html),
  [`CcipRead`](https://ethers.hexdocs.pm/Ethers.Contracts.CcipRead.html) and
  [`UniversalSigValidator`](https://ethers.hexdocs.pm/Ethers.Contracts.UniversalSigValidator.html):
  used internally, and available to you as well

They all live under `Ethers.Contracts`. The token interfaces have no default address, so pass the
contract address as `to:` (or `address:` for `Ethers.get_logs/2`), as in the
[Quick start](#quick-start).

### ENS

[`Ethers.NameService`](https://ethers.hexdocs.pm/Ethers.NameService.html) resolves ENS names and
ENS-compatible name services, in both directions.

```elixir
Ethers.NameService.resolve("vitalik.eth")
#=> {:ok, "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045"}

Ethers.NameService.reverse_resolve("0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045")
#=> {:ok, "vitalik.eth"}
```

### Gas fees and simulation

Estimate EIP-1559 fees from recent blocks:

```elixir
Ethers.estimate_fees()
#=> {:ok, %{max_fee_per_gas: 334398307, max_priority_fee_per_gas: 11098767}}

Ethers.estimate_fees(speed: :fast)
```

Run a call against modified chain state without sending anything. Here an address is given a
balance of 100 ETH for the duration of the call:

```elixir
burn = "0x000000000000000000000000000000000000dEaD"

Ethers.Contracts.Multicall3.get_eth_balance(burn)
|> Ethers.call(state_overrides: %{burn => %{balance: Ethers.Utils.to_wei(100)}})
#=> {:ok, 100000000000000000000}
```

[`Ethers.StateOverride`](https://ethers.hexdocs.pm/Ethers.StateOverride.html) describes everything
that can be overridden: balances, nonces, code and storage. Related functions in the
[`Ethers`](https://ethers.hexdocs.pm/Ethers.html) module:

- `Ethers.estimate_gas/2` estimates the gas of a transaction, and accepts `:state_overrides` too.
- `Ethers.create_access_list/2` returns an access list that can be passed back as the
  `:access_list` option of `Ethers.send_transaction/2`.
- `Ethers.fee_history/4` returns decoded `eth_feeHistory` data.
- `Ethers.config/1` returns the current and upcoming fork configuration of the node (EIP-7910).

## Signing

### Signers

A signer is a module that implements the
[`Ethers.Signer`](https://ethers.hexdocs.pm/Ethers.Signer.html) behaviour. Two are built in:

- [`Ethers.Signer.Local`](https://ethers.hexdocs.pm/Ethers.Signer.Local.html) signs with a private
  key. It needs the `ex_secp256k1` dependency.
- [`Ethers.Signer.JsonRPC`](https://ethers.hexdocs.pm/Ethers.Signer.JsonRPC.html) asks a node or a
  signing service such as [web3signer](https://github.com/Consensys/web3signer) to sign over
  JSON-RPC.

Pass `:signer` and `:signer_opts` on each call, as in [Send transactions](#send-transactions), or
set a default once:

```elixir
# config/runtime.exs
config :ethers,
  default_signer: Ethers.Signer.Local,
  default_signer_opts: [private_key: System.fetch_env!("ETH_PRIVATE_KEY")]
```

> [!WARNING]
> Keep private keys out of source control and compile-time config. Handling raw keys in production
> needs care. A remote signer keeps them out of your application entirely.

The examples in the rest of this section assume a default signer is configured.

### Messages and typed data

[`Ethers.personal_sign/2`](https://ethers.hexdocs.pm/Ethers.html#personal_sign/2) signs an EIP-191
personal message, and
[`Ethers.PersonalMessage`](https://ethers.hexdocs.pm/Ethers.PersonalMessage.html) recovers the
signer.

```elixir
{:ok, signature} = Ethers.personal_sign("Hello world")
#=> {:ok, "0x15a3fe39...4d00c9891b"}

Ethers.PersonalMessage.recover("Hello world", signature)
#=> {:ok, "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"}
```

[`Ethers.sign_typed_data/2`](https://ethers.hexdocs.pm/Ethers.html#sign_typed_data/2) signs EIP-712
typed structured data built with
[`Ethers.TypedData`](https://ethers.hexdocs.pm/Ethers.TypedData.html).

```elixir
typed_data =
  Ethers.TypedData.new!(
    primary_type: "Mail",
    types: %{
      "Mail" => [
        %{name: "to", type: "address"},
        %{name: "contents", type: "string"}
      ]
    },
    domain: [name: "Ether Mail", version: "1", chain_id: 1],
    message: %{
      "to" => "0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB",
      "contents" => "Hello, Bob!"
    }
  )

{:ok, signature} = Ethers.sign_typed_data(typed_data)

Ethers.TypedData.recover_signer(typed_data, signature)
#=> "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
```

The [EIP-712 guide](https://ethers.hexdocs.pm/eip-712.html) covers nested types, hashing, and
declaring typed data as Elixir structs.

> [!IMPORTANT]
> Recovering the signer only works for plain key-pair accounts. Smart-contract wallets (Safe,
> ERC-4337 and EIP-7702 accounts) cannot produce signatures that recover to their address, so a
> backend that only recovers will reject those users. Verify with `Ethers.Signature` instead.

[`Ethers.Signature`](https://ethers.hexdocs.pm/Ethers.Signature.html) verifies a signature from any
account, including smart-contract wallets (ERC-1271) and wallets that are not deployed yet
(ERC-6492):

```elixir
signer = "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"

Ethers.Signature.verify_message("Hello world", signature, signer)
#=> {:ok, true}

Ethers.Signature.verify_typed_data(typed_data, signature, signer)
#=> {:ok, true}
```

For wallet login, [`Ethers.Siwe`](https://ethers.hexdocs.pm/Ethers.Siwe.html) implements Sign-In
with Ethereum (EIP-4361). The [SIWE guide](https://ethers.hexdocs.pm/siwe.html) walks through a
Phoenix example.

### EIP-7702 authorizations

An EIP-7702 authorization lets an externally owned account delegate to contract code. Sign one with
[`Ethers.sign_authorization/2`](https://ethers.hexdocs.pm/Ethers.html#sign_authorization/2) and
include it in a type 4 transaction. The chain id and nonce are fetched when not given.

```elixir
account = "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
delegate = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"

# `executor: :self` because the account sends the transaction itself
{:ok, authorization} = Ethers.sign_authorization(%{address: delegate}, executor: :self)

{:ok, tx_hash} =
  Ethers.send_transaction(%{},
    from: account,
    to: account,
    type: Ethers.Transaction.Eip7702,
    authorization_list: [authorization]
  )

# Once the transaction is included
Ethers.get_delegation(account)
#=> {:ok, "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"}
```

> [!WARNING]
> An authorization with a mismatched nonce does not fail the transaction. It is skipped silently
> on chain, so always confirm the result with `Ethers.get_delegation/2`.

> [!NOTE]
> `Ethers.Signer.JsonRPC` cannot sign authorizations, because there is no standard RPC method for
> it.

## Features

- **Contract modules from ABIs**: functions, events and errors generated at compile time, with docs and typespecs ([`Ethers.Contract`](https://ethers.hexdocs.pm/Ethers.Contract.html))
- **Calls and transactions**: legacy, EIP-2930, EIP-1559, EIP-4844 and EIP-7702 transaction types ([`Ethers`](https://ethers.hexdocs.pm/Ethers.html), [`Ethers.Transaction`](https://ethers.hexdocs.pm/Ethers.Transaction.html))
- **Events**: typed filters, combined filters and decoded logs ([`Ethers.EventFilter`](https://ethers.hexdocs.pm/Ethers.EventFilter.html), [`Ethers.Event`](https://ethers.hexdocs.pm/Ethers.Event.html))
- **Built-in contracts**: ERC-20, ERC-721, ERC-1155, ERC-777, ERC-165 and Multicall3
- **Batching**: Multicall3 aggregation and JSON-RPC batch requests ([`Ethers.Multicall`](https://ethers.hexdocs.pm/Ethers.Multicall.html), [`Ethers.batch/2`](https://ethers.hexdocs.pm/Ethers.html#batch/2))
- **ENS**: forward and reverse resolution, with EIP-3668 CCIP-Read ([`Ethers.NameService`](https://ethers.hexdocs.pm/Ethers.NameService.html))
- **Pluggable signers**: local private key, JSON-RPC, or your own ([`Ethers.Signer`](https://ethers.hexdocs.pm/Ethers.Signer.html))
- **Message signing**: EIP-191 personal messages and EIP-712 typed data ([`Ethers.PersonalMessage`](https://ethers.hexdocs.pm/Ethers.PersonalMessage.html), [`Ethers.TypedData`](https://ethers.hexdocs.pm/Ethers.TypedData.html))
- **Universal signature verification**: EOAs, ERC-1271 smart-contract wallets and ERC-6492 counterfactual wallets ([`Ethers.Signature`](https://ethers.hexdocs.pm/Ethers.Signature.html))
- **Sign-In with Ethereum**: build, parse, validate and verify EIP-4361 messages ([`Ethers.Siwe`](https://ethers.hexdocs.pm/Ethers.Siwe.html))
- **EIP-7702**: sign authorizations, send type 4 transactions and inspect delegations ([`Ethers.Authorization`](https://ethers.hexdocs.pm/Ethers.Authorization.html))
- **Fees and simulation**: fee estimation, access lists, state overrides and the EIP-7825 gas cap ([`Ethers.StateOverride`](https://ethers.hexdocs.pm/Ethers.StateOverride.html))
- **Any EVM chain**: works with every chain that speaks the Ethereum JSON-RPC API, through [Ethereumex](https://github.com/mana-ethereum/ethereumex) or your own RPC client

### Requirements

Ethers requires Elixir 1.15 or later. CI tests Elixir 1.19 and 1.20 on Erlang/OTP 28 and 29.

> [!NOTE]
> EIP-4844 transactions can be built, signed and decoded but not broadcast, because blob sidecars
> are not supported yet.

## Documentation

- [API reference](https://ethers.hexdocs.pm), starting with the [`Ethers`](https://ethers.hexdocs.pm/Ethers.html) module
- [Configuration guide](https://ethers.hexdocs.pm/configuration.html): RPC endpoints and HTTP options, default signer, gas margins, replacing the keccak, JSON and secp256k1 modules
- [Typed arguments guide](https://ethers.hexdocs.pm/typed-arguments.html): calling overloaded contract functions
- [EIP-712 typed data guide](https://ethers.hexdocs.pm/eip-712.html)
- [Sign-In with Ethereum guide](https://ethers.hexdocs.pm/siwe.html)
- [Upgrade guide](https://ethers.hexdocs.pm/upgrading.html) and [changelog](https://ethers.hexdocs.pm/changelog.html)

> [!TIP]
> **For LLMs and coding agents:** [llms.txt](https://ethers.hexdocs.pm/llms.txt) indexes every
> page, and any docs page is also available as Markdown by replacing `.html` with `.md`.

## Contributing

Contributions are welcome, from typo fixes to new features. See
[CONTRIBUTING.md](https://github.com/ExWeb3/elixir_ethers/blob/main/CONTRIBUTING.md) for the
development setup and how to run the tests. To report a vulnerability, follow the
[security policy](https://github.com/ExWeb3/elixir_ethers/blob/main/SECURITY.md).

## Acknowledgements

Ethers was possible to make thanks to the great contributors of the following libraries.

- [ABI](https://github.com/poanetwork/ex_abi)
- [Ethereumex](https://github.com/mana-ethereum/ethereumex)
- [ExKeccak](https://github.com/tzumby/ex_keccak)

And also all the people who contributed to this project in any ways.

## License

[Apache License 2.0](https://github.com/ExWeb3/elixir_ethers/blob/main/LICENSE)
