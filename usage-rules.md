# Rules for working with Ethers

## Understanding Ethers

Ethers is an Elixir library for Ethereum and other EVM chains. It generates an Elixir module from a
contract ABI at compile time, and the functions of that module build values which the functions of
the `Ethers` module then execute. Read the documentation of `Ethers` and of the generated contract
module before using them. Do not assume it works like ethers.js, viem or web3.js: there is no
provider, wallet or contract instance object to create or pass around.

## Core rules

- A contract function such as `MyToken.balance_of(holder)` performs no I/O. It returns an
  `Ethers.TxData` struct. Pipe it into `Ethers.call/2` to read, `Ethers.send_transaction/2` to
  write, or `Ethers.estimate_gas/2` to estimate.
- Define contract modules with `use Ethers.Contract, abi_file: "priv/abi/my_token.json"`, and
  optionally `default_address: "0x..."`. The ABI is read at compile time.
- Solidity names become snake case: `balanceOf` is `balance_of/1`. Do not guess function names or
  arities. Read the ABI, or the generated docs with `h MyToken.balance_of` in IEx.
- For ERC-20, ERC-721, ERC-1155, ERC-777 and ERC-165 use the built-in modules such as
  `Ethers.Contracts.ERC20` instead of adding an ABI file. They have no default address, so always
  pass `to: address` (`address: address` for `Ethers.get_logs/2`).
- Functions that reach the network return `{:ok, value}` or `{:error, reason}`, and have a `!`
  variant that returns the value or raises `Ethers.ExecutionError`. Use the `!` variant instead of
  `{:ok, value} = ...` when a failure should crash.
- Configure the RPC endpoint with `config :ethereumex, url: "https://..."`. To use a different
  endpoint for one call, for example in a multi-chain application, pass `rpc_opts: [url: "..."]`.
- Do not call `Ethereumex` or `ABI` directly for something `Ethers` already does.

## Values

- Addresses are `"0x"`-prefixed hex strings. Ethers accepts any casing and returns them EIP-55
  checksummed. Normalize both sides with `Ethers.Utils.to_checksum_address/1` before comparing two
  addresses.
- `uint` and `int` values are integers. Amounts are integers in the smallest unit (wei for ether).
  Convert with `Ethers.Utils.to_wei/1` and `Ethers.Utils.from_wei/1`. Never pass a float or a hex
  string as an amount.
- `bytes` and `bytesN` values are raw binaries, not hex strings. Convert with
  `Ethers.Utils.hex_decode!/1` and `Ethers.Utils.hex_encode/1`.
- Transaction hashes and block hashes are `"0x"`-prefixed hex strings.
- Solidity arrays are lists, and tuples and structs are tuples.

## Topic rules

More rules for each area are in the `usage-rules` directory of this package:

- `usage-rules/contracts.md`: calling contracts, errors, batching, deployment
- `usage-rules/transactions.md`: sending transactions, signers, receipts, fees
- `usage-rules/events.md`: event filters and logs
- `usage-rules/signing.md`: signing and verifying messages and typed data

## Documentation

The guides ship with the package in its `guides` directory, and are published with the API
reference at https://ethers.hexdocs.pm. https://ethers.hexdocs.pm/llms.txt indexes every page.
