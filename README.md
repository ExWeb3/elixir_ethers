
# Elixir Ethers

[![example workflow](https://github.com/alisinabh/elixir_ethers/actions/workflows/elixir.yml/badge.svg)](https://github.com/alisinabh/elixir_ethers)
[![Coverage Status](https://coveralls.io/repos/github/alisinabh/elixir_ethers/badge.svg?branch=main)](https://coveralls.io/github/alisinabh/elixir_ethers?branch=main)
[![Module Version](https://img.shields.io/hexpm/v/ethers.svg)](https://hex.pm/packages/ethers)
[![Hex Docs](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/ethers/)
[![License](https://img.shields.io/hexpm/l/ethers.svg)](https://github.com/alisinabh/elixir_ethers/blob/master/LICENSE.md)
[![Last Updated](https://img.shields.io/github/last-commit/alisinabh/elixir_ethers.svg)](https://github.com/alisinabh/elixir_ethers/commits/main)


<img width="100" align="left" src="https://github.com/alisinabh/elixir_ethers/raw/main/assets/ethers_logo.png" alt="Ethers Elixir">

Elixir Ethers is a comprehensive library for interacting with the Ethereum blockchain and its ecosystem. 
Heavily inspired by the [ethers.js](https://github.com/ethers-io/ethers.js/) library, Elixir Ethers leverages macros to convert
Ethereum contract ABIs into first-class Elixir modules during compile time, complete with documentation and type-specs.

## Installation

You can install the package by adding `ethers` to the list of dependencies in your `mix.exs` file::

```elixir
def deps do
  [
    {:ethers, "~> 0.0.4"}
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
end
```

### Calling contract functions

After defining the module, all the functions can be called like any other Elixir module.
The documentation is also available giving the developer a first-class experience.

```elixir
# Calling functions on the blockchain
iex> MyERC20Token.balance_of("0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2")
{:ok, [654294510138460920346]}

# Get the documentation of a function
iex> h MyERC20Token.balance_of
                     def balance_of(owner, overrides \\ [])

  @spec balance_of(Ethers.Types.t_address(), Keyword.t()) ::
          {:ok, [non_neg_integer()]}
          | {:ok, Ethers.Types.t_hash()}
          | {:ok, Ethers.Contract.t_function_output()}
          | {:error, term()}

Executes balanceOf(address _owner) on the contract.

Default action for this function is `:call`. To override default action see
Execution Options in Ethers.Contract.

## Parameters

  • _owner: `:address`
  • overrides: Overrides and options for the call. See Execution Options in
    Ethers.Contract.

## Return Types

  • {:uint, 256}
```

### Sending transaction


Sending transactions is also straightforward, as Elixir Ethers automatically determines whether a function is a view function or a state-changing function, using `eth_call` or `eth_sendTransaction` accordingly.
You can override this behavior with the `:action` override.

Ensure that you specify a `from` option to inform your client which account to use:


```elixir
iex> MyERC20Token.transfer("0x[Recipient Address Here]", Ethers.Utils.to_wei(1), from: "0x[Your address here]")
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

### Resolving Ethereum (ENS) names in Elixir

To resolve ENS or any other name service provider in the blockchain
you can simply use the [`Ethers.NameService`](https://hexdocs.pm/ethers/Ethers.NameService.html) module.

```elixir
iex> Ethers.NameService.resolve("vitalik.eth")
{:ok, "0xd8da6bf26964af9d7eed9e03e53415d37aa96045"}
```

## Contributing

All contributions to this project are welcome. Please feel free to open issues and push PRs.

To run the tests locally, the only dependency is [ganache](https://github.com/trufflesuite/ganache).
After installing ganache, just run the following in a new window the you can run the tests on
the same machine.

```
> ganache --wallet.deterministic
```

## Props

This project was not possible if it was not for the great [:ex_abi](https://github.com/poanetwork/ex_abi) library and its contributors.

Also a special thanks to the authors and contributors of [:ethereumex](https://github.com/mana-ethereum/ethereumex) library.

## License

[Apache License 2.0](https://github.com/alisinabh/elixir_ethers/blob/main/LICENSE)
