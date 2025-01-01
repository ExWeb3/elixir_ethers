# Changelog

## v0.6.0 (2025-01-01)

### Breaking Changes

- Removed `Ethers.Transaction` struct and replaced with separate EIP-1559 and Legacy transaction structs for improved type safety
- Deprecated `Ethers.Transaction.from_map/1` - use `Ethers.Transaction.from_rpc_map/1` instead for RPC response parsing
- Deprecated `Ethers.Utils.maybe_add_gas_limit/2` - gas limits should now be set explicitly
- Changed input format requirements: All inputs to `Ethers` functions must use native types (e.g., integers) instead of hex strings encoded values
- Removed auto-gas estimation from send_transaction calls
- `tx_type` option in transaction overrides has been replaced with `type`, now requiring explicit struct modules (e.g. `Ethers.Transaction.Eip1559`, `Ethers.Transaction.Legacy`)
- Moved `Ethers.Transaction.calculate_y_parity_or_v/1` to `Ethers.Transaction.Signed` module
- Deprecate `Ethers.send/2` in favor of `Ethers.send_transaction/2` for clarity and prevent collision with `Kernel.send/2`.

### New features

- Added **EIP-3668 CCIP-Read** support via `Ethers.CcipRead` module for off-chain data resolution
- Extended NameService to handle off-chain and cross-chain name resolution using CCIP-Read protocol
- Introduced `Ethers.Transaction.Protocol` behaviour for improved transaction handling
- Added dedicated _EIP-1559_ and _Legacy_ transaction struct types with validation
- New address utilities: `Ethers.Utils.decode_address/1` and `Ethers.Utils.encode_address/1`
- Added `Transaction.decode/1` to decode raw transactions

### Enhancements

- Improved error handling and reporting in `Ethers.deploy/2`
- Enhanced NameService with ENSIP-10 wildcard resolution support
- Use checksum addresses when decoding transactions
- Add bang versions of `Ethers` top module functions which were missing

## v0.5.5 (2024-12-03)

### Enhancements

- Add `from_block` and `to_block` options to `Ethers.get_logs/2`
- Add RPC adapter behaviour and proxy for Ethereumex.HttpClient
- Move and export abi decode functionality to `Ethers.TxData` module
- Export `Ethers.TxData.to_map/2` in docs
- Add `Ethers.Event.find_and_decode/2` function

## v0.5.4 (2024-10-22)

### Bug fixes

- Handle `nil` values when decoding transaction values for RLP encoding

## v0.5.3 (2024-10-14)

### Enhancements

- Make event filter arguments optional in typespecs

## v0.5.2 (2024-08-08)

### Bug fixes

- Handle `{:ok, nil}` from RPC get block by number request

### Enhancements

- Enable raw use of `Ethers.call/2` (usage without function selector)
- Add optional backoff to `Ethers.Utils.date_to_block_number/3`

## v0.5.1 (2024-08-02)

### Enhancements

- Mark `ex_keccak` as optional using SKIP_EX_KECCAK environment variable

## v0.5.0 (2024-05-29)

### Breaking Changes

- Rename `NotERC165CompatibleError` to `Errors.NotERC165CompatibleError`

### Bug fixes

- Handle unexpected errors in ExecutionError exceptions

## v0.4.5 (2024-04-27)

### Enhancements

- Add `Ethers.NameService.reverse_resolve/2` to reverse resolve addresses to domains

## v0.4.4 (2024-04-17)

### Enhancements

- Add ERC-165 contract and behaviour
- Add `skip_docs` option for contract module doc and typespec generation
- Allow skipping checksum address in `Ethers.Utils.public_key_to_address/2`

## v0.4.3 (2024-04-05)

### Bug fixes

- Fix `Ethers.Multicall` typespecs

## v0.4.2 (2024-04-04)

### Enhancements

- Support sending raw transactions using `Ethers.send/2`
- Add `Ethers.get_transaction_count/2`

## v0.4.1 (2024-04-02)

### Enhancements

- Add support of getting current `max_priority_fee_per_gas`
- Use latest `max_priority_fee_per_gas` from the chain as default value in transactions

## v0.4.0 (2024-03-11)

### Breaking Changes

- Custom errors will be returned as error structs instead of raw RPC response
- Updated ERC20, ERC721 and ERC1155 ABIs to Openzeppelin 5.x

### Enhancements

- Generate error structs from ABI and decode custom errors when error data is available
- Use JsonRPC signer as a default signer in `Ethers.sign_transaction/2`

## v0.3.1 (2024-03-05)

### Bug fixes

- Fix trimmed zeros in transaction encoder with unified hex encoding for transaction

## v0.3.0 (2024-02-05)

### Breaking Changes

- Removed `signature_v`, `signature_recovery_id` and `signature_y_parity` from `Ethers.Transaction`
  struct and introduce new `signature_v_or_y_parity` value
- Update `ex_abi` to 0.7.0 with new `method_id` logic for event selectors and use its value

### Enhancements

- Cleanup implementation of Transaction encoders and value decoder

## v0.2.3 (2024-01-29)

### New features

- Add `Ethers.get_transaction_receipt/2` function to query native chain transaction receipt by transaction hash.

### Enhancements

- Add more metadata to `Ethers.Transaction` struct.
- Return `Ethers.Transaction` struct in `Ethers.get_transaction/2` function.
- Support `get_transaction` in batch requests.

## v0.2.2 (2024-01-08)

### New features

- Add `Ethers.get_transaction/2` function to query native chain transaction by transaction hash.

## v0.2.1 (2024-01-04)

### New features

- Add `Ethers.get_balance/2` function to query native chain balance of accounts.

### Bug fixes

- Encode integers to hex even when they are part of params

## v0.2.0 (2024-01-01)

### New Features

- `Ethers.sign_transaction/2` function
- Signer behaviour
- Local Signer implementation
- JsonRPC Signer implementation
- `Ethers.Transaction` struct and helper functions

## v0.1.3 (2023-12-26)

### Bug fixes

- unsized integer encoding to hex will now raise if given negative numbers.
- `Utils.date_to_block_number/3` going to negative block numbers issue fixed.

## v0.1.2 (2023-12-12)

### Breaking Changes

- `TxData.to_map/2` now returns hex values for all integers.
- `Utils.maybe_add_gas_limit/2` now adds hex gas limit value instead of integer.

## v0.1.1 (2023-11-22)

### Bug fixes

- Multicall: aggregate_3 decoder returns `nil` in case of failure
- Multicall: Feed decoded results through `Utils.human_arg/2`

## v0.1.0 (2023-11-19)

### New Features

- Checksum address utility functions

### Enhancements

- Use zip_reduce for event generators
- Move documentation generators to ContractHelpers
- Display message for empty parameters or return types
- `Ethers.call/2` and `Ethers.get_logs/2` now automatically convert integer block numbers to hex values
- Return structs as a result in generated functions and event filter with Inspection protocols implemented for better development experience
- Support dynamically sized indexed event filters (bytes, strings, arrays and structs)
- `Ethers.call/2` now only returns as a list if the return type is either a solidity array or tuple
- Add return names in documentations and TxData inspection
- Added an interface for `Multicall3` through `Ethers.Contracts.Multicall3`
- Added `Ethers.Multicall` as an abstraction for `Ethers.Contracts.Multicall3`
- Added batching functionality using `Ethers.batch/2`

### Breaking Changes

- The generated contract functions no longer call or send transactions, They will only prepare parameters
  To execute an explicit call to `Ethers.send/2` or `Ethers.call/2` is required
- Events no longer accept `address` overrides. Overriding now happens at `Ethers.get_logs/2`
- Function `Ethers.get_logs/3` is now changed to `Ethers.get_logs/2`
- Generated contract modules and EventFilter modules `default_address/0` function is now renamed to `__default_address__/0` to prevent collision
- Removal of `Ethers.RPC` module
- Remove `Ethers.Types.dynamically_sized_types/0` function
- `Ethers.call/2` response is not always a list
- `Ethers.deploy/4` is now removed and replaced with `Ethers.deploy/2`

### Bug fixes

- Fix event filters with mixed indexed and non-indexed arguments

## v0.0.6 (2023-09-06)

### Enhancements

- Update `dialyxir` dependency to 1.4.0
- Update `ex_doc` to 0.30.6
- Add more function to `Utils` module
- Improve failure return values of deployment functions

### Bug fixes

- Fix RPC options and client override issue
- Do not add `nil` to address when address is not present

## v0.0.5 (2023-08-21)

### Enhancements

- Add ENS (Ethereum name service) contracts and helper functions
- Update `ex_doc` dependency to 0.30.4
- Address `Logger.warn` deprecation

## v0.0.4 (2023-07-14)

### Enhancements

- Update `ex_doc` dependency to 0.30.1
- Update `jason` dependency to 1.4.1

## v0.0.3 (2023-05-29)

### Enhancements

- Improved generative documentation for modules
- Improved gas estimation API
- Add gas limit to sending transactions
- Remove redundant gas estimation function

### Bug fixes

- Fix bitsize check guard to include all available solidity bitsizes

## v0.0.2 (2023-04-24)

### Bug fixes

- Include the priv directory in mix releases

## v0.0.1 (2023-04-24)

First Release
