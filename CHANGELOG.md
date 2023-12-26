# Changelog

## v0.1.3 (2023-12-26)

## Bug fixes

- unsized integer encoding to hex will now raise if given negative numbers.
- `Utils.date_to_block_number/3` going to negative block numbers issue fixed.

## v0.1.2 (2023-12-12)

### Breaking Changes

- `TxData.to_map/2` now returns hex values for all integers.
- `Utils.maybe_add_gas_limit/2` now adds hex gas limit value instead of integer.

### New Features

- `Ethers.sign_transaction/2` function
- Signer behaviour
- Local Signer implementation
- JsonRPC Signer implementation
- `Ethers.Transaction` struct and helper functions

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
- Generated contract modules and EventFilter modules `default_address/0` function is now renamed to `__default_adress__/0` to prevent collision
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
- Add gas limit to sending trasnactions
- Remove redundant gas estimation function

### Bug fixes

- Fix bitsize check guard to include all available solidity bitsizes

## v0.0.2 (2023-04-24)

### Bug fixes

- Include the priv directory in mix releases

## v0.0.1 (2023-04-24)

First Release
