
<img height="120" align="left" src="https://github.com/alisinabh/elixir_ethers/raw/main/assets/ethers_logo.png" alt="Ethers Elixir">

# Elixir Ethers

[![example workflow](https://github.com/alisinabh/elixir_ethers/actions/workflows/elixir.yml/badge.svg)](https://github.com/alisinabh/elixir_ethers)
[![Coverage Status](https://coveralls.io/repos/github/alisinabh/elixir_ethers/badge.svg?branch=main)](https://coveralls.io/github/alisinabh/elixir_ethers?branch=main)
[![Module Version](https://img.shields.io/hexpm/v/ethers.svg)](https://hex.pm/packages/ethers)
[![Hex Docs](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/ethers/)
[![License](https://img.shields.io/hexpm/l/ethers.svg)](https://github.com/alisinabh/elixir_ethers/blob/master/LICENSE.md)
[![Last Updated](https://img.shields.io/github/last-commit/alisinabh/elixir_ethers.svg)](https://github.com/alisinabh/elixir_ethers/commits/main)

Ethers is a comprehensive Web3 library for interacting with smart contracts on the Ethereum (Or any EVM based blockchain) using Elixir.

Inspired by [ethers.js](https://github.com/ethers-io/ethers.js/) and [web3.js](https://web3js.readthedocs.io/), Ethers leverages 
Elixir's amazing meta-programming capabilities to generate Elixir modules for give smart contracts from their ABI.
It also generates beautiful documentation for those modules which can further help developers.

## Installation

You can install the package by adding `ethers` to the list of dependencies in your `mix.exs` file::

```elixir
def deps do
  [
    {:ethers, "~> 0.0.6"}
  ]
end
```

The complete documentation is available on [hexdocs](https://hexdocs.pm/ethers).

## Configuration

To use Elixir Ethers, ensure you have a configured JSON-RPC endpoint.
Configure the endpoint using the following configuration parameter.


```elixir
# config.exs
config :ethers,
  rpc_client: Ethereumex.HttpClient, # Defaults to: Ethereumex.HttpClient
  keccak_module: ExKeccak, # Defaults to: ExKeccak
  json_module: Jason # Defaults to: Jason

# If using Ethereumex, you need to specify a JSON-RPC server url here
config :ethereumex, url: "[URL_HERE]"
```

You can use [Cloudflare's Ethereum Gateway](https://developers.cloudflare.com/web3/ethereum-gateway/reference/supported-networks/) `https://cloudflare-eth.com/v1/mainnet` for the RPC URL.

For more configuration options, refer to [ethereumex](https://github.com/mana-ethereum/ethereumex#configuration).

To send transactions, you need a wallet client capable of signing transactions and exposing a JSON-RPC endpoint.

## Usage

To use Elixir Ethers, you must have your contract's ABI in json format, which can be obtained from [etherscan.io](https://etherscan.io). 
This library also contains standard contract interfaces such as `ERC20`, `ERC721` and some more by default (refer to built-in contracts in hex-doc).

Create a module for your contract as follows:

```elixir
defmodule MyERC20Token do
  use Ethers.Contract, 
    abi_file: "path/to/abi.json", 
    default_address: "[Token address here (optional)]"

  # You can also add more code here in this module if you wish
end
```

### Generated documentation for functions and event filters

Ethers generates documentation for all the functions and event filters based on the ABI data.
To get the documentation you can either use the `h/1` IEx helper function or generate HTML/epub docs using ExDoc.

#### Get the documentation of a contract function

```elixir
iex(3)> h MyERC20Token.balance_of

                             def balance_of(owner)

  @spec balance_of(Ethers.Types.t_address()) ::
          Ethers.Contract.t_function_output()

Executes balanceOf(address _owner) on the contract.

This function should only be called for result and never in a transaction on
its own. (Use Ethers.call/2)

State mutability: view

## Function Parameter Types

  • _owner: `:address`

## Return Types (when called with `Ethers.call/2`)

  • {:uint, 256}
```

#### Get the documentation of a event filter

```elixir
iex(4)> h MyERC20Token.EventFilters.transfer

                             def transfer(from, to)

  @spec transfer(Ethers.Types.t_address(), Ethers.Types.t_address()) ::
          Ethers.Contract.t_event_output()

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

### Calling contract functions

After defining the module, all the functions can be called like any other Elixir module.
To make a call (eth_call) to the blockchain, you can use `Ethers.call/2` function.

```elixir
# Calling functions on the blockchain
iex> MyERC20Token.balance_of("0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2") |> Ethers.call()
{:ok, [654294510138460920346]}
```

### Sending transaction

To send transaction (eth_sendTransaction) to the blockchain, you can use the `Ethers.send/2` function.
Ensure that you specify a `from` option to inform your client which account to use:

```elixir
iex> MyERC20Token.transfer("0x[Recipient Address]", 1000) |> Ethers.send(from: "0x[Sender address]")
{:ok, "0xf313ff7ff54c6db80ad44c3ad58f72ff0fea7ce88e5e9304991ebd35a6e76000"}
```

### Getting Logs (Events)

Elixir Ethers provides functionality for creating event filters and fetching events from the RPC endpoint using `eth_getLogs`. 
Each contract in Ethers generates an `EventFilters` module (e.g. `MyERC20Token.EventFilter`s) that can be used to create filters for events.

To create an event filter and use the [`Ethers.get_logs/3`](https://hexdocs.pm/ethers/Ethers.html#get_logs/3) function, follow this example:

```elixir
iex> filter = MyERC20Token.EventFilters.transfer("0x[From Address Here]", nil)

# Also `nil` can be used for a parameter in EventFilters functions to show that it should not be filtered.
# Then you can simply list the logs.

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

To resolve ENS or any other name service provider in the blockchain
you can simply use the [`Ethers.NameService`](https://hexdocs.pm/ethers/Ethers.NameService.html) module.

```elixir
iex> Ethers.NameService.resolve("vitalik.eth")
{:ok, "0xd8da6bf26964af9d7eed9e03e53415d37aa96045"}
```

### Built-in contract interfaces

Ethers already includes some of the well-known contract interface standards for you to use. Here is a list of them.

 - [ERC20](https://hexdocs.pm/ethers/Ethers.Contracts.ERC20.html) - The well know fungible token standard
 - [ERC721](https://hexdocs.pm/ethers/Ethers.Contracts.ERC721.html) - Non-Fungible tokens (NFTs) standard
 - [ERC777](https://hexdocs.pm/ethers/Ethers.Contracts.ERC777.html) - Improved fungible token standard
 - [ERC1155](https://hexdocs.pm/ethers/Ethers.Contracts.ERC1155.html) - Multi-Token standard (Fungible, Non-Fungible or Semi-Fungible)

To use them you just need to specify the target contract address (`:to` option) of your token and call the functions. e.g.

```elixir
iex> Ethers.Contracts.ERC20.balance_of("0xWALLET_ADDRESS", to: "0xTOKEN_ADDRESS")
```

## Contributing

All contributions to this project are very welcome. Please feel free to open issues and push PRs and even share your
suggestions.

To run the tests locally, you need to run [ganache](https://github.com/trufflesuite/ganache).
After installing ganache, just run the following in a new window the you can run the tests on
the same machine.

```
> ganache --wallet.deterministic
```

## Acknowledgements

This project was not possible if it was not for the great [:ex_abi](https://github.com/poanetwork/ex_abi) library and its contributors.

Also a special thanks to the authors and contributors of [:ethereumex](https://github.com/mana-ethereum/ethereumex) library.

## License

[Apache License 2.0](https://github.com/alisinabh/elixir_ethers/blob/main/LICENSE)
