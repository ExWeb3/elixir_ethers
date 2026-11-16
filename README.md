<img height="120" align="left" src="https://github.com/ExWeb3/elixir_ethers/raw/main/assets/ethers_logo.png" alt="Ethers Elixir">

# Elixir Ethers

[![CI](https://github.com/ExWeb3/elixir_ethers/actions/workflows/elixir.yml/badge.svg)](https://github.com/ExWeb3/elixir_ethers/actions/workflows/elixir.yml)
[![Coverage Status](https://coveralls.io/repos/github/ExWeb3/elixir_ethers/badge.svg?branch=main)](https://coveralls.io/github/ExWeb3/elixir_ethers?branch=main)
[![Module Version](https://img.shields.io/hexpm/v/ethers.svg)](https://hex.pm/packages/ethers)
[![Hex Docs](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://ethers.hexdocs.pm)
[![License](https://img.shields.io/hexpm/l/ethers.svg)](https://github.com/ExWeb3/elixir_ethers/blob/main/LICENSE)

Ethers is a Web3 library for Elixir for interacting with smart contracts on Ethereum and other
EVM-based blockchains. It generates an Elixir module, with documentation and typespecs, from a
contract ABI at compile time, and covers calls, transactions, events, signing and signature
verification.

[Installation](#installation) · [Quick start](#quick-start) · [Usage](#usage) · [Signing](#signing) · [Compatibility](#compatibility) · [Documentation](#documentation)

## Features

| Capability | Entry point | Standard |
|---|---|---|
| Contract modules generated from ABIs | [`Ethers.Contract`](https://ethers.hexdocs.pm/Ethers.Contract.html) | Solidity ABI |
| Read calls and transactions | [`Ethers.call/2`](https://ethers.hexdocs.pm/Ethers.html#call/2), [`Ethers.send_transaction/2`](https://ethers.hexdocs.pm/Ethers.html#send_transaction/2) | Transaction types 0 to 4 |
| Events and logs | [`Ethers.get_logs/2`](https://ethers.hexdocs.pm/Ethers.html#get_logs/2), [`Ethers.EventFilter`](https://ethers.hexdocs.pm/Ethers.EventFilter.html) | |
| Built-in contracts | [`Ethers.Contracts.*`](#built-in-contracts) | ERC-20, 165, 721, 777, 1155 |
| Many calls in one request | [`Ethers.Multicall`](https://ethers.hexdocs.pm/Ethers.Multicall.html), [`Ethers.batch/2`](https://ethers.hexdocs.pm/Ethers.html#batch/2) | Multicall3, JSON-RPC batch |
| Name resolution | [`Ethers.NameService`](https://ethers.hexdocs.pm/Ethers.NameService.html) | ENS, EIP-3668 CCIP-Read |
| Transaction signing | [`Ethers.Signer`](https://ethers.hexdocs.pm/Ethers.Signer.html) | EIP-155 |
| Message signing | [`Ethers.personal_sign/2`](https://ethers.hexdocs.pm/Ethers.html#personal_sign/2), [`Ethers.PersonalMessage`](https://ethers.hexdocs.pm/Ethers.PersonalMessage.html) | EIP-191 |
| Typed data ([guide](https://ethers.hexdocs.pm/eip-712.html)) | [`Ethers.TypedData`](https://ethers.hexdocs.pm/Ethers.TypedData.html), [`Ethers.sign_typed_data/2`](https://ethers.hexdocs.pm/Ethers.html#sign_typed_data/2) | EIP-712 |
| Signature verification for any wallet | [`Ethers.Signature`](https://ethers.hexdocs.pm/Ethers.Signature.html) | ERC-1271, ERC-6492 |
| Sign-In with Ethereum ([guide](https://ethers.hexdocs.pm/siwe.html)) | [`Ethers.Siwe`](https://ethers.hexdocs.pm/Ethers.Siwe.html) | EIP-4361 |
| Account delegation | [`Ethers.sign_authorization/2`](https://ethers.hexdocs.pm/Ethers.html#sign_authorization/2), [`Ethers.get_delegation/2`](https://ethers.hexdocs.pm/Ethers.html#get_delegation/2) | EIP-7702 |
| Fee estimation and access lists | [`Ethers.estimate_fees/1`](https://ethers.hexdocs.pm/Ethers.html#estimate_fees/1), [`Ethers.create_access_list/2`](https://ethers.hexdocs.pm/Ethers.html#create_access_list/2) | EIP-1559, EIP-2930 |
| Simulation with state overrides | [`Ethers.StateOverride`](https://ethers.hexdocs.pm/Ethers.StateOverride.html) | `eth_call` state override set |

## Installation

Add `ethers` to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ethers, "~> 1.0"},
    # Optional: required for Ethers.Signer.Local and for recovering signers locally
    {:ex_secp256k1, "~> 0.7"}
  ]
end
```

Ethers requires Elixir 1.15 or later (see [Compatibility](#compatibility)).

Upgrading from 0.8 or earlier? See the [upgrade guide](https://ethers.hexdocs.pm/upgrading.html).

## Quick start

1. Point Ethers at a JSON-RPC endpoint. Use the URL of your node or provider, or pick a public
   one from [chainlist.org](https://chainlist.org/).

```elixir
# config/config.exs
config :ethereumex, url: "https://your-ethereum-node.example"
```

2. Call a contract. Ethers ships with the ERC-20 interface, so this reads the symbol of the
   WETH token on Ethereum mainnet:

```elixir
iex> Ethers.Contracts.ERC20.symbol() |> Ethers.call(to: "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2")
{:ok, "WETH"}
```

3. Generate a module for your own contract from its ABI. The ABI JSON can be downloaded from a
   block explorer such as [etherscan.io](https://etherscan.io) or produced by your compiler.

```elixir
defmodule MyToken do
  use Ethers.Contract,
    abi_file: "priv/abi/my_token.json",
    # Optional. Without it, pass `to: address` on each call.
    default_address: "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"
end
```

Every function and event of the ABI is now a documented Elixir function (try `h MyToken.balance_of`
in IEx). The rest of this page uses `MyToken` for a module like this one, generated from an ERC-20
ABI.

## Usage

### Read contract state

A contract function returns an `Ethers.TxData` struct. It describes the call and does not touch
the network until you pipe it into [`Ethers.call/2`](https://ethers.hexdocs.pm/Ethers.html#call/2).

```elixir
iex> MyToken.balance_of("0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045")
#Ethers.TxData<
  function balanceOf(
    address account "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045"
  ) view returns (
    uint256
  )
  default_address: "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"
>

iex> MyToken.balance_of("0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045") |> Ethers.call()
{:ok, 1468927766030343079}
```

`Ethers.call/2` returns `{:ok, value}` for a single return value and `{:ok, [values]}` for several.
`Ethers.call!/2` returns the bare value or raises.

To make many calls in one round trip, use
[`Ethers.Multicall`](https://ethers.hexdocs.pm/Ethers.Multicall.html) (one `eth_call` through the
Multicall3 contract) or [`Ethers.batch/2`](https://ethers.hexdocs.pm/Ethers.html#batch/2) (one
JSON-RPC batch request):

```elixir
iex> Ethers.batch([
...>   {:call, MyToken.symbol()},
...>   :current_block_number,
...>   {:get_balance, "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045"}
...> ])
{:ok, [ok: "WETH", ok: 26425608, ok: 5798969845714110716]}
```

If a contract has overloaded functions with the same number of arguments, see the
[typed arguments guide](https://ethers.hexdocs.pm/typed-arguments.html).

### Send transactions

Pipe the same kind of `Ethers.TxData` into
[`Ethers.send_transaction/2`](https://ethers.hexdocs.pm/Ethers.html#send_transaction/2). It returns
the transaction hash. `:from` is required.

```elixir
iex> signer = [
...>   signer: Ethers.Signer.Local,
...>   signer_opts: [private_key: System.fetch_env!("ETH_PRIVATE_KEY")]
...> ]

iex> {:ok, tx_hash} =
...>   MyToken.transfer("0x70997970C51812dc3A010C7d01b50e0d17dc79C8", 1000)
...>   |> Ethers.send_transaction([from: "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"] ++ signer)
{:ok, "0x873d06f74640306bdde9f079536b8a6c70e12b6cbe1e30b71c391bd1794c0f4c"}

iex> {:ok, receipt} = Ethers.get_transaction_receipt(tx_hash)
iex> receipt.status
:success
```

> **Note:** Without a `:signer`, Ethers sends `eth_sendTransaction` and relies on the node to
> sign. Public RPC endpoints do not hold your keys, so they cannot do that. See
> [Signing](#signing).

Other options include `:value` (in wei), `:gas`, `:nonce`, `:type` and the fee fields; anything
not given is filled in from the network. The full list is in the
[`Ethers.send_transaction/2`](https://ethers.hexdocs.pm/Ethers.html#send_transaction/2) docs. To
deploy a contract, see [`Ethers.deploy/2`](https://ethers.hexdocs.pm/Ethers.html#deploy/2).

### Events

Each contract module has an `EventFilters` module with one function per event. Pass `nil` for an
indexed argument you do not want to filter on, then fetch the logs with
[`Ethers.get_logs/2`](https://ethers.hexdocs.pm/Ethers.html#get_logs/2).

```elixir
iex> filter = MyToken.EventFilters.transfer(nil, nil)
iex> Ethers.get_logs(filter, from_block: 26_425_607, to_block: 26_425_607)
{:ok,
 [
   %Ethers.Event{
     address: "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2",
     block_hash: "0x689371fca9da4fe412553a094b5360a9077ea1d078203eee9efd9a4ccdb6df00",
     block_number: 26425607,
     data_raw: "0x00000000000000000000000000000000000000000000000000410d34cdecfebf",
     topics: ["Transfer(address,address,uint256)",
      "0x000000000004444c5dc75cB358380D2e3dE08A90",
      "0x0000000aa232009084Bd71A5797d089AA4Edfad4"],
     topics_raw: ["0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef",
      "0x000000000000000000000000000000000004444c5dc75cb358380d2e3de08a90",
      "0x0000000000000000000000000000000aa232009084bd71a5797d089aa4edfad4"],
     transaction_hash: "0xdea835593a1eb84c0a95085ab363a204a804407c5d27c26b8ab083cda7d132d7",
     transaction_index: 0,
     data: [18310393930514111],
     log_index: 1,
     removed: false
   },
   ...
 ]}
```

`topics` holds the event signature followed by the decoded indexed arguments, and `data` holds the
decoded non-indexed arguments.

```elixir
# Several events in one request (the filters are OR-ed)
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

These interfaces ship with Ethers. The token interfaces have no default address, so pass the
contract address as `to:` (or `address:` for `Ethers.get_logs/2`), as in the
[Quick start](#quick-start).

| Module | Interface |
|---|---|
| [`Ethers.Contracts.ERC20`](https://ethers.hexdocs.pm/Ethers.Contracts.ERC20.html) | Fungible tokens |
| [`Ethers.Contracts.ERC721`](https://ethers.hexdocs.pm/Ethers.Contracts.ERC721.html) | Non-fungible tokens (NFTs) |
| [`Ethers.Contracts.ERC1155`](https://ethers.hexdocs.pm/Ethers.Contracts.ERC1155.html) | Multi-token standard |
| [`Ethers.Contracts.ERC777`](https://ethers.hexdocs.pm/Ethers.Contracts.ERC777.html) | Fungible tokens with hooks |
| [`Ethers.Contracts.ERC165`](https://ethers.hexdocs.pm/Ethers.Contracts.ERC165.html) | Interface detection |
| [`Ethers.Contracts.Multicall3`](https://ethers.hexdocs.pm/Ethers.Contracts.Multicall3.html) | [Multicall3](https://www.multicall3.com/), used by `Ethers.Multicall` |
| [`Ethers.Contracts.ENS`](https://ethers.hexdocs.pm/Ethers.Contracts.ENS.html) | ENS contracts, used by `Ethers.NameService` |
| [`Ethers.Contracts.CcipRead`](https://ethers.hexdocs.pm/Ethers.Contracts.CcipRead.html) | EIP-3668 off-chain lookup, used by `Ethers.CcipRead` |
| [`Ethers.Contracts.UniversalSigValidator`](https://ethers.hexdocs.pm/Ethers.Contracts.UniversalSigValidator.html) | ERC-6492 validator, used by `Ethers.Signature` |

### ENS

[`Ethers.NameService`](https://ethers.hexdocs.pm/Ethers.NameService.html) resolves ENS names and
ENS-compatible name services, in both directions.

```elixir
iex> Ethers.NameService.resolve("vitalik.eth")
{:ok, "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045"}

iex> Ethers.NameService.reverse_resolve("0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045")
{:ok, "vitalik.eth"}
```

### Gas fees and simulation

```elixir
# EIP-1559 fees from recent blocks. Also accepts speed: :slow | :standard | :fast
iex> Ethers.estimate_fees()
{:ok, %{max_fee_per_gas: 334398307, max_priority_fee_per_gas: 11098767}}

# Run a call against modified chain state: here, with a spoofed ETH balance
iex> burn = "0x000000000000000000000000000000000000dEaD"
iex> Ethers.Contracts.Multicall3.get_eth_balance(burn)
...> |> Ethers.call(state_overrides: %{burn => %{balance: Ethers.Utils.to_wei(100)}})
{:ok, 100000000000000000000}
```

Related functions, all documented in the [`Ethers`](https://ethers.hexdocs.pm/Ethers.html) module:

- `Ethers.estimate_gas/2` estimates the gas of a transaction. It accepts `:state_overrides` too
  (see [`Ethers.StateOverride`](https://ethers.hexdocs.pm/Ethers.StateOverride.html)).
- `Ethers.create_access_list/2` returns an access list that can be passed back as the
  `:access_list` option of `Ethers.send_transaction/2`.
- `Ethers.fee_history/4` returns decoded `eth_feeHistory` data.
- `Ethers.config/1` returns the current and upcoming fork configuration of the node (EIP-7910).

## Signing

### Signers

A signer is a module that implements the
[`Ethers.Signer`](https://ethers.hexdocs.pm/Ethers.Signer.html) behaviour. Two are built in:

- [`Ethers.Signer.Local`](https://ethers.hexdocs.pm/Ethers.Signer.Local.html) signs with a private
  key given as `signer_opts: [private_key: key]`. It needs the `ex_secp256k1` dependency.
- [`Ethers.Signer.JsonRPC`](https://ethers.hexdocs.pm/Ethers.Signer.JsonRPC.html) asks a node or a
  signing service such as [web3signer](https://github.com/Consensys/web3signer) to sign over
  JSON-RPC.

Pass `:signer` and `:signer_opts` per call, as in [Send transactions](#send-transactions), or set
a default once:

```elixir
# config/runtime.exs
config :ethers,
  default_signer: Ethers.Signer.Local,
  default_signer_opts: [private_key: System.fetch_env!("ETH_PRIVATE_KEY")]
```

> **Warning:** Keep private keys out of source control and compile-time config. Handling raw keys
> in production needs care; a remote signer keeps them out of your application.

### Messages and typed data

[`Ethers.personal_sign/2`](https://ethers.hexdocs.pm/Ethers.html#personal_sign/2) signs an EIP-191
personal message. The examples below assume a default signer is configured.

```elixir
iex> {:ok, signature} = Ethers.personal_sign("Hello world")
{:ok, "0x15a3fe3974ebe469b00e67ad67bb3860ad3fc3d739287cdbc4ba558ce7130bee205e5e38d6ef156f1ff6a4df17bfa72a1e61c429f92613f3efbc58394d00c9891b"}

iex> Ethers.PersonalMessage.recover("Hello world", signature)
{:ok, "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"}
```

[`Ethers.sign_typed_data/2`](https://ethers.hexdocs.pm/Ethers.html#sign_typed_data/2) signs EIP-712
typed structured data built with [`Ethers.TypedData`](https://ethers.hexdocs.pm/Ethers.TypedData.html):

```elixir
typed_data =
  Ethers.TypedData.new!(
    types: %{
      "Mail" => [%{name: "to", type: "address"}, %{name: "contents", type: "string"}]
    },
    primary_type: "Mail",
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

Recovering the signer only works for plain key-pair accounts. To verify a signature from any
account, including smart-contract wallets (ERC-1271) and wallets that are not deployed yet
(ERC-6492), use [`Ethers.Signature`](https://ethers.hexdocs.pm/Ethers.Signature.html):

```elixir
iex> Ethers.Signature.verify_message("Hello world", signature, "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266")
{:ok, true}
```

`Ethers.Signature.verify_typed_data/4` and `Ethers.Signature.verify_hash/4` do the same for typed
data and raw digests. For wallet login, [`Ethers.Siwe`](https://ethers.hexdocs.pm/Ethers.Siwe.html)
implements Sign-In with Ethereum (EIP-4361); see the
[SIWE guide](https://ethers.hexdocs.pm/siwe.html).

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

> **Note:** An authorization with a mismatched nonce does not fail the transaction; it is skipped
> on chain. Check the result with `Ethers.get_delegation/2`. `Ethers.Signer.JsonRPC` cannot sign
> authorizations.

## Compatibility

| | Supported |
|---|---|
| Elixir | 1.15 or later is required. CI tests Elixir 1.19 and 1.20. |
| Erlang/OTP | CI tests OTP 28 and 29. |
| Transaction types | Legacy (0), EIP-2930 (1), EIP-1559 (2, the default), EIP-4844 (3) and EIP-7702 (4). EIP-4844 transactions can be built, signed and decoded but not broadcast, because blob sidecars are not supported. |
| Signing and verification | EIP-155, EIP-191, EIP-712, EIP-4361, ERC-1271, ERC-6492 |
| Other standards | ENS, EIP-3668 CCIP-Read, EIP-7825 gas limit cap, EIP-7910 `eth_config` |
| Chains | Any EVM chain that speaks the Ethereum JSON-RPC API |
| RPC client | [Ethereumex](https://github.com/mana-ethereum/ethereumex) by default. Replaceable through the `:rpc_client` [configuration option](https://ethers.hexdocs.pm/configuration.html). |

## Documentation

- [API reference](https://ethers.hexdocs.pm), starting with the [`Ethers`](https://ethers.hexdocs.pm/Ethers.html) module
- [Configuration guide](https://ethers.hexdocs.pm/configuration.html): RPC endpoints and HTTP options, default signer, gas margins, replacing the keccak, JSON and secp256k1 modules
- [Typed arguments guide](https://ethers.hexdocs.pm/typed-arguments.html): calling overloaded contract functions
- [EIP-712 typed data guide](https://ethers.hexdocs.pm/eip-712.html)
- [Sign-In with Ethereum guide](https://ethers.hexdocs.pm/siwe.html)
- [Upgrade guide](https://ethers.hexdocs.pm/upgrading.html) and [changelog](https://ethers.hexdocs.pm/changelog.html)
- **For LLMs and coding agents:** [llms.txt](https://ethers.hexdocs.pm/llms.txt) indexes every page, and any docs page is also available as Markdown by replacing `.html` with `.md`.

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
