<img height="120" align="left" src="https://github.com/ExWeb3/elixir_ethers/raw/main/assets/ethers_logo.png" alt="Ethers Elixir">

# Elixir Ethers

[![example workflow](https://github.com/ExWeb3/elixir_ethers/actions/workflows/elixir.yml/badge.svg)](https://github.com/ExWeb3/elixir_ethers)
[![Coverage Status](https://coveralls.io/repos/github/ExWeb3/elixir_ethers/badge.svg?branch=main)](https://coveralls.io/github/ExWeb3/elixir_ethers?branch=main)
[![Module Version](https://img.shields.io/hexpm/v/ethers.svg)](https://hex.pm/packages/ethers)
[![Hex Docs](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/ethers/)
[![License](https://img.shields.io/hexpm/l/ethers.svg)](https://github.com/ExWeb3/elixir_ethers/blob/master/LICENSE.md)
[![Last Updated](https://img.shields.io/github/last-commit/ExWeb3/elixir_ethers.svg)](https://github.com/ExWeb3/elixir_ethers/commits/main)

Ethers is a powerful Web3 library for Elixir that makes interacting with Ethereum and other
EVM-based blockchains simple and intuitive.
It leverages Elixir's metaprogramming capabilities to provide a seamless developer experience.

## Key Features

- **Smart Contract Integration**: Generate Elixir modules from contract ABIs with full documentation
- **Built-in Contracts**: Ready-to-use interfaces for [ERC20](https://hexdocs.pm/ethers/Ethers.Contracts.ERC20.html), [ERC721](https://hexdocs.pm/ethers/Ethers.Contracts.ERC721.html), [ERC1155](https://hexdocs.pm/ethers/Ethers.Contracts.ERC1155.html), and more
- **Multi-chain Support**: Works with any EVM-compatible blockchain
- **Flexible Signing**: Extensible signer support with [built-in ones](https://hexdocs.pm/ethers/readme.html#signing-transactions)
- **Event Handling**: Easy filtering and retrieval of blockchain events
- **Multicall Support**: Ability to easily perform multiple `eth_call`s using [Multicall 2/3](https://hexdocs.pm/ethers/Ethers.Multicall.html)
- **Type Safety**: Native Elixir types for all contract interactions
- **ENS Support**: Out of the box [Ethereum Name Service (ENS)](https://ens.domains/) support
- **Comprehensive Documentation**: Auto-generated docs for all contract functions

## Installation

Add `ethers` to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ethers, "~> 0.6.4"},
    # Uncomment next line if you want to use local signers
    # {:ex_secp256k1, "~> 0.7.2"}
  ]
end
```

For upgrading from versions prior to `0.6.0`, see our [Upgrade Guide](guides/upgrading.md).

## Quick Start

1. **Configure your RPC endpoint**:

```elixir
# config/config.exs
config :ethereumex, url: "https://eth.llamarpc.com"
```

2. **Create a contract module**:

```elixir
defmodule MyContract do
  use Ethers.Contract,
    abi_file: "path/to/abi.json",
    default_address: "0x..." # Optional contract address
end
```

3. **Start interacting with the blockchain**:

```elixir
# Read contract state
{:ok, result} =
  MyContract.my_function("0x...")
  |> Ethers.call()

# Send a transaction
{:ok, tx_hash} =
  MyToken.my_function("0x...", 1000)
  |> Ethers.send_transaction(from: "0x...")
```

Read full documentation of Ethers for detailed information at [HexDocs](https://hexdocs.pm/ethers).

## Common Use Cases

### Reading Contract State

```elixir
{:ok, erc20_symbol} =
  Ethers.Contracts.ERC20.symbol()
  |> Ethers.call()

# With parameters
{:ok, balance} =
  Ethers.Contracts.ERC20.balance_of("0x[Wallet]")
  |> Ethers.call()
```

See `Ethersm.Multicall` if you want to perform multiple calls in a single
eth_call request.

### Writing to Contracts

```elixir
# Simple transaction
{:ok, tx_hash} =
  MyContract.set_value(123)
  |> Ethers.send_transaction(from: address)

# With Ether (chain native token) transfer (value is in wei)
{:ok, tx_hash} =
  MyContract.deposit()
  |> Ethers.send_transaction(from: address, value: 1_000_000)
```

### Working with Events

```elixir
# Create an event filter (nil = any)
filter = MyToken.EventFilters.transfer(from_address, nil)

# Get matching events
{:ok, events} = Ethers.get_logs(filter)
```

## Documentation

Complete API documentation is available at [HexDocs](https://hexdocs.pm/ethers).

- [Configuration Guide](guides/configuration.md) - Detailed configuration options
- [Upgrade Guide](guides/upgrading.md) - Version upgrade instructions
- [Built-in Contracts](#built-in-contract-interfaces-in-ethers) - Standard contract interfaces

## Configuration

To get started with Ethers, you'll need to configure a JSON-RPC endpoint. Here's a minimal configuration:

```elixir
# Configure the JSON-RPC endpoint URL
config :ethereumex, url: "https://your-ethereum-node.com"
```

You can use one of the RPC URLs for your chain/wallet of choice or try out one from
[chainlist.org](https://chainlist.org/).

For detailed configuration options, environment-specific setups, best practices, and
troubleshooting, please refer to our [Configuration Guide](guides/configuration.md).

## Custom ABIs

To use Elixir Ethers, you must have your contract's ABI in json format, which can be obtained from
[etherscan.io](https://etherscan.io). This library also contains standard contract interfaces such
as `ERC20`, `ERC721` and some more by default (refer to built-in contracts in
[hexdocs](https://hexdocs.pm/ethers)).

Create a module for your contract as follows:

```elixir
defmodule MyContract do
  use Ethers.Contract,
    abi_file: "path/to/abi.json",
    default_address: "0x[Contract address here (optional)]"

  # You can also add more code here in this module if you wish
end
```

### Calling contract functions

After defining the module, all the functions can be called like any other Elixir module. These
functions will return an `Ethers.TxData` struct which can be used later on to perform on-chain
calls or send transactions.

To fetch the results (return value(s)) of a function you can pass your function result to the
[`Ethers.call/2`](https://hexdocs.pm/ethers/Ethers.html#call/2) function.

#### Example

```elixir
# Calling functions on the blockchain
iex> MyContract.balance_of("0x[Address]") |> Ethers.call()
{:ok, 654294510138460920346}
```

Refer to [Ethers.call/2](https://hexdocs.pm/ethers/Ethers.html#call/2) for more information.

### Sending transaction

To send transaction (eth_sendTransaction) to the blockchain, you can use the
[`Ethers.send_transaction/2`](https://hexdocs.pm/ethers/Ethers.html#send_transaction/2) function.

Ensure that you specify a `from` option to inform your client which account to use as the signer:

#### Example

```elixir
iex> MyContract.transfer("0x[Recipient]", 1000) |> Ethers.send_transaction(from: "0x[Sender]")
{:ok, "0xf313ff7ff54c6db80ad44c3ad58f72ff0fea7ce88e5e9304991ebd35a6e76000"}
```

Refer to [Ethers.send_transaction/2](https://hexdocs.pm/ethers/Ethers.html#send_transaction/2) for more information.

### Getting Logs (Events)

Ethers provides functionality for creating event filters and fetching related events from the
blockchain. Each contract generated by Ethers also will have `EventFilters` module
(e.g. `MyERC20Token.EventFilters`) that can be used to create filters for events.

To create an event filter and then use
[`Ethers.get_logs/2`](https://hexdocs.pm/ethers/Ethers.html#get_logs/2) function like the below
example.

#### Example

```elixir
# Create The Event Filter
# (`nil` can be used for a parameter in EventFilters functions to indicate no filtering)
iex> filter = MyContract.EventFilters.transfer("0x[From Address Here]", nil)

# Then you can simply list the logs using `Ethers.get_logs/2`

iex> Ethers.get_logs(filter)
{:ok,
 [
   %Ethers.Event{
     address: "0x5883c66ca442461d406f330775d42954bfcf7d92",
     block_hash: "0x83de67fd285067b838790406ea68f21a3afbc0ade534047725b5ccfb904c9ed3",
     block_number: 17077047,
     topics: ["Transfer(address,address,uint256)",
      "0x6b75d8af000000e20b7a7ddf000ba900b4009a80",
      "0x230507f6a391ae5ac0ec124f1c5b8ce454fe3f3d"],
     topics_raw: ["0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef",
      "0x0000000000000000000000006b75d8af000000e20b7a7ddf000ba900b4009a80",
      "0x000000000000000000000000230507f6a391ae5ac0ec124f1c5b8ce454fe3f3d"],
     transaction_hash: "0xaa6fb2e1bbb27f667e76b03e8cde23db694207e06b9aa810d4c20c1f109a58e5",
     transaction_index: 0,
     data: [761112156078097834180608],
     log_index: 0,
     removed: false
   },
   %Ethers.Event{...},
    ...
 ]}
```

### Resolving Ethereum names (ENS domains) using Ethers

To resolve ENS or any other name service provider (which are ENS compatible) in the blockchain
you can simply use [`Ethers.NameService`](https://hexdocs.pm/ethers/Ethers.NameService.html) module.

```elixir
iex> Ethers.NameService.resolve("vitalik.eth")
{:ok, "0xd8da6bf26964af9d7eed9e03e53415d37aa96045"}
```

### Built-in contract ABIs in Ethers

Ethers already includes some of the well-known contract interface standards for you to use.
Here is a list of them.

- [ERC20](https://hexdocs.pm/ethers/Ethers.Contracts.ERC20.html) - The well know fungible token standard
- [ERC165](https://hexdocs.pm/ethers/Ethers.Contracts.ERC165.html) - Standard Interface detection
- [ERC721](https://hexdocs.pm/ethers/Ethers.Contracts.ERC721.html) - Non-Fungible tokens (NFTs) standard
- [ERC777](https://hexdocs.pm/ethers/Ethers.Contracts.ERC777.html) - Improved fungible token standard
- [ERC1155](https://hexdocs.pm/ethers/Ethers.Contracts.ERC1155.html) - Multi-Token standard (Fungible, Non-Fungible or Semi-Fungible)
- [Multicall](https://hexdocs.pm/ethers/Ethers.Multicall.html) - [Multicall3](https://www.multicall3.com/)

To use them you just need to specify the target contract address (`:to` option) of your token and
call the functions. Example:

```elixir
iex> tx_data = Ethers.Contracts.ERC20.balance_of("0x[Holder Address]")
#Ethers.TxData<
  function balanceOf(
    address _owner "0x[Holder Address]"
  ) view returns (
    uint256 balance
  )
>

iex> Ethers.call(tx_data, to: "0x[Token Address]")
{:ok, 123456}
```

### Generated documentation for functions and event filters

Ethers generates documentation for all the functions and event filters based on the ABI data.
To get the documentation you can either use the `h/1` IEx helper function or generate HTML/epub
docs using ExDoc.

#### Get the documentation of a contract function

```elixir
iex(3)> h MyERC20Token.balance_of

                             def balance_of(owner)

  @spec balance_of(Ethers.Types.t_address()) :: Ethers.TxData.t()

Prepares balanceOf(address _owner) call parameters on the contract.

This function should only be called for result and never in a transaction on
its own. (Use Ethers.call/2)

State mutability: view

## Function Parameter Types

  • _owner: `:address`

## Return Types (when called with `Ethers.call/2`)

  • balance: {:uint, 256}
```

#### Inspecting TxData and EventFilter structs

One cool and potentially useful feature of Ethers is how you can inspect the call

#### Get the documentation of a event filter

```elixir
iex(4)> h MyERC20Token.EventFilters.transfer

                             def transfer(from, to)

  @spec transfer(Ethers.Types.t_address(), Ethers.Types.t_address()) ::
          Ethers.EventFilter.t()

Create event filter for Transfer(address from, address to, uint256 value)

For each indexed parameter you can either pass in the value you want to filter
or nil if you don't want to filter.

## Parameter Types (Event indexed topics)

  • from: :address
  • to: :address

## Event `data` Types (when called with `Ethers.get_logs/2`)

These are non-indexed topics (often referred to as data) of the event log.

  • value: {:uint, 256}
```

## Signing Transactions

By default, Ethers will rely on the default blockchain endpoint to handle the signing (using `eth_sendTransaction` RPC function). Obviously public endpoints cannot help you with signing the transactions since they do not hold your private keys.

To sign transactions on Ethers, You can specify a `signer` module when sending/signing transactions. A signer module is a module which implements the [Ethers.Signer](lib/ethers/signer.ex) behaviour.

Ethers has these built-in signers to use:

- `Ethers.Signer.Local`: A local signer which loads a private key from `signer_opts` and signs the transactions.
- `Ethers.Signer.JsonRPC`: Uses `eth_signTransaction` Json RPC function to sign transactions. (Using services like [Consensys/web3signer](https://github.com/Consensys/web3signer) or [geth](https://geth.ethereum.org/))

For more information on signers, visit [hexdocs](https://hexdocs.pm/ethers/Ethers.Signer.html).

### Example

```elixir
MyERC20Token.transfer("0x[Recipient]", 1000)
|> Ethers.send_transaction(
  from: "0x[Sender]",
  signer: Ethers.Signer.Local,
  signer_opts: [private_key: "0x..."]
)
```

## Switching the ex_keccak library

`ex_keccak` is a Rustler NIF that brings keccak256 hashing to elixir.
It is the default used library in `ex_abi` and `ethers`. If for some reason you need to use a
different library (e.g. target does not support rustler) you can use the Application config value
and on top of that set the environment variable `SKIP_EX_KECCAK=true` so ex_keccak is marked as
optional in hex dependencies.

```elixir
# config.exs
config :ethers, keccak_module: MyKeccakModule

# Also make sure to set SKIP_EX_KECCAK=true when fetching dependencies and building them
```

## Contributing

All contributions are very welcome (as simple as fixing typos). Please feel free to open issues and
push Pull Requests. Just remember to be respectful to everyone!

To run the tests locally, follow below steps:

- Install [ethereum](https://geth.ethereum.org/docs/getting-started/installing-geth) and [solc](https://docs.soliditylang.org/en/latest/installing-solidity.html). For example, on MacOS

```
brew install ethereum
npm install -g solc
```

- Run [anvil (from foundry)](https://book.getfoundry.sh/getting-started/installation).
  After installing anvil, just run the following in a new window

```
> anvil
```

Then you should be able to run tests through `mix test`.

## Acknowledgements

Ethers was possible to make thanks to the great contributors of the following libraries.

- [ABI](https://github.com/poanetwork/ex_abi)
- [Ethereumex](https://github.com/mana-ethereum/ethereumex)
- [ExKeccak](https://github.com/tzumby/ex_keccak)

And also all the people who contributed to this project in any ways.

## License

[Apache License 2.0](https://github.com/ExWeb3/elixir_ethers/blob/main/LICENSE)
