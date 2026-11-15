# Upgrade Guide

This guide provides information about upgrading between different versions of Ethers and handling breaking changes.

## Upgrading to 1.0.0

### Transaction RPC Maps

#### Decoded access lists and blob hashes in fetched transactions

`Ethers.get_transaction/2` and `Ethers.Transaction.from_rpc_map/1` now decode `accessList` and
`blobVersionedHashes` into binaries: the same form `Ethers.Transaction.decode/1` produces and the
`:access_list` and `:blob_versioned_hashes` overrides accept. Code that read the RPC maps or hex
strings from these fields needs to handle binaries instead.

```elixir
{:ok, tx} = Ethers.get_transaction(tx_hash)
[entry] = tx.payload.access_list

# Before (0.8.x)
%{"address" => address, "storageKeys" => storage_keys} = entry

# After (1.0.0)
[address_bin, storage_key_bins] = entry
address = Ethers.Utils.encode_address!(address_bin)
storage_keys = Enum.map(storage_key_bins, &Ethers.Utils.hex_encode/1)
```

#### Access lists and authorizations in JSON-RPC params

`Ethers.Transaction.to_rpc_map/1`, which builds the transaction params sent to the node, now
emits access list entries as objects, as the JSON-RPC spec requires (geth rejected the old
arrays). It also emits EIP-7702 authorization `r` and `s` as quantities without leading zeros.

This affects custom RPC client adapters, which receive these maps as params for `eth_call`,
`eth_estimateGas`, `eth_createAccessList` and `eth_sendTransaction`. It also affects custom
`Ethers.Signer` implementations that build their request with `to_rpc_map/1`, as
`Ethers.Signer.JsonRPC` does. The `:access_list` override you pass to `Ethers` functions is
unchanged.

```
// Before (0.8.x)
{
  "accessList": [["0x90F8bf6A479f320ead074411a4B0e7944Ea8c9C1", ["0x00...01"]]],
  "authorizationList": [{"r": "0x0078f561...2143", "s": "0x014ae7c1...c3cf", ...}]
}

// After (1.0.0)
{
  "accessList": [
    {"address": "0x90F8bf6A479f320ead074411a4B0e7944Ea8c9C1", "storageKeys": ["0x00...01"]}
  ],
  "authorizationList": [{"r": "0x78F56157...2143", "s": "0x14AE7C15...C3CF", ...}]
}
```

#### `ArgumentError` for unsupported values

`Ethers.Transaction.to_rpc_map/1` now raises `ArgumentError` naming the field and value, instead
of `FunctionClauseError`, when a field holds a value it cannot encode. This includes access list
storage keys and blob versioned hashes that are not 32-byte binaries (for example hex strings),
which used to be passed on to the node. Pass these values as binaries.

## Upgrading to 0.6.x

Version 0.6.x and onwards introduce several breaking changes to improve type safety and explicitness.
Here's what you need to know:

### Key Changes

#### Native Elixir Types

All inputs to functions now require native Elixir types

Example: Use integers instead of hex strings
```elixir
# Before (0.5.x)
Ethers.call(ERC20.name(), gas: "0x1")

# After (0.6.x)
Ethers.call(ERC20.name(), gas: 1)
```

#### Explicit Gas Limits

When sending transactions without a signer, the gas limit (and no other field) will not be
automatically set. Only when using a signer, these values will be fetched from the network for you.

```elixir
# Before (0.5.x)
MyContract.my_function() |> Ethers.send_transaction()

# After (0.6.x)
MyContract.my_function() |> Ethers.send_transaction(gas: 100_000)
```

#### Transaction Types

Transaction struct split into separate EIP-1559, EIP-4844 and EIP-2930 and Legacy types.

```elixir
# Before (0.5.x)
Ethers.send_transaction(tx, tx_type: :eip1559)

# After (0.6.x)
Ethers.send_transaction(tx, type: Ethers.Transaction.Eip1559)
```

### Function Changes

#### Transaction Sending

Use `Ethers.send_transaction/2` instead of `Ethers.send/2`

```elixir
# Before (0.5.x)
Ethers.send(tx)

# After (0.6.x)
Ethers.send_transaction(tx)
```

#### Transaction Creation

Use `Ethers.Transaction.from_rpc_map/1` instead of `from_map/1`

```elixir
# Before (0.5.x)
Ethers.Transaction.from_map(tx_map)

# After (0.6.x)
Ethers.Transaction.from_rpc_map(tx_map)
```

### Migration Checklist

1. [ ] Update all function inputs to use native Elixir types
2. [ ] Add explicit gas limits to all transactions
3. [ ] Update transaction type specifications
4. [ ] Replace deprecated function calls
5. [ ] Test all contract interactions

## Upgrading from Earlier Versions

For upgrades from versions prior to 0.5.x, please refer to the [CHANGELOG.md](../CHANGELOG.md) file. 