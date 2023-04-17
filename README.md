# Elixir Ethers

![example workflow](https://github.com/alisinabh/elixir_ethers/actions/workflows/elixir.yml/badge.svg)
[![Module Version](https://img.shields.io/hexpm/v/ethers.svg)](https://hex.pm/packages/ethers)
[![Hex Docs](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/ethers/)
[![License](https://img.shields.io/hexpm/l/ethers.svg)](https://github.com/alisinabh/elixir_ethers/blob/master/LICENSE.md)
[![Last Updated](https://img.shields.io/github/last-commit/alisinabh/elixir_ethers.svg)](https://github.com/alisinabh/elixir_ethers/commits/master)


Elixir Ethers is a comprehensive library for interacting with the Ethereum blockchain and its ecosystem. 
Heavily inspired by the [ethers.js](https://github.com/ethers-io/ethers.js/) library, Elixir Ethers leverages macros to convert
Ethereum contract ABIs into first-class Elixir modules during compile time, complete with documentation and type-specs.

## Installation

You can install the package by adding `ethers` to the list of dependencies in your `mix.exs` file::

```elixir
def deps do
  [
    {:ethers, "~> 0.1.0-dev", github: "alisinabh/elixir-ethers"}
  ]
end
```

The complete documentation is available on [hexdocs](https://hexdocs.pm/ethers).

## Requirements


To use Elixir Ethers, ensure you have a configured JSON-RPC endpoint.
By default, Ethers utilizes [Cloudflare's Ethereum Gateway](https://developers.cloudflare.com/web3/ethereum-gateway/reference/supported-networks/).

To send transactions, you need a wallet client capable of signing transactions and exposing a JSON-RPC endpoint.
Configure the endpoint using the following config parameter (you can also specify the endpoint per-call):

```elixir
# config.exs
import Config

config :ethereumex, url: "[URL_HERE]"
```

For more information, refer to [ethereumex](https://github.com/mana-ethereum/ethereumex#configuration).

## Usage

To use Elixir Ethers, you must have your contract's ABI, which can be obtained from [etherscan.io](https://etherscan.io). 
This library also supports standard contract interfaces such as `ERC20`, `ERC721` and some more (refer to built-in contracts in hex-doc).

Create a module for your contract as follows:

```elixir
defmodule MyERC20Token do
  use Ethers.Contract, abi_file: "path/to/abi.json", default_address: "[Token address here (optional)]"
end
```

### Calling contract functions

After defining the module, all the functions can be called like any other Elixir module.
The documentation is also available giving the developer a first-class experience.

```elixir
iex> MyERC20Token.balance_of("0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2")
{:ok, [654294510138460920346]}

iex> h MyERC20Token.balance_of
                     def balance_of(owner, overrides \\ [])

  @spec balance_of(Ethers.Types.t_address(), Keyword.t()) ::
          {:ok, [non_neg_integer()]}
          | {:ok, Ethers.Types.t_transaction_hash()}
          | {:ok, Ethers.Contract.t_function_output()}

Executes balanceOf(address _owner) on the contract.

## Parameters

  • _owner: `:address`
  • overrides: Overrides and options for the call.
    • :to: The address of the recipient contract. (Required)
    • :action: Type of action for this function (:call, :send or
      :prepare) Default: :call.
    • :rpc_opts: Options to pass to the RCP client e.g. :url.


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

To create an event filter and use the `Ethers.get_logs` function, follow this example:

```elixir
iex> {:ok, filter} = MyERC20Token.EventFilters.transfer("0x[From Address Here]", nil)
```

Also `nil` can be used for a parameter in EventFilters functions to show that it should not be filtered.

Then you can simply list the logs.

```elixir
iex> Ethers.get_logs(filter)
{:ok,
  [
    %{
      "address" => "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2",
      "blockHash" => "0xd04d7d39f0dd6913260f1682e1863eda9b5dc0a5d4cf2dca4ef6961147a77f39",
      "blockNumber" => "0x1046dd0",
      "data" => [1274604842999873536],
      "logIndex" => "0x0",
      "removed" => false,
      "topics" => ["0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef",
      "0x0000000000000000000000006b75d8af000000e20b7a7ddf000ba900b4009a80",
      "0x0000000000000000000000009b3df8eae6e1ed1b931086852860d3c6375d7ae6"],
      "transactionHash" => "0xd00e58a817c42f46709bea153c44b7908d88d4763472836a85e7c740dd481d69",
      "transactionIndex" => "0x3"
    },
    ...
  ]
}
```

## License

[Apache License 2.0](https://github.com/alisinabh/elixir_ethers/blob/main/LICENSE)
