# Upgrade Guide

This guide provides information about upgrading between different versions of Ethers and handling breaking changes.

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