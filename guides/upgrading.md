# Upgrade Guide

This guide provides information about upgrading between different versions of Ethers and handling breaking changes.

## Upgrading to 1.0.0

### Transaction RPC Maps

#### Decoded access lists and blob hashes in fetched transactions

`Ethers.get_transaction/2` and `Ethers.Transaction.from_rpc_map/1` now return `access_list` and
`blob_versioned_hashes` as binaries, the same form the `:access_list` and `:blob_versioned_hashes`
overrides accept.

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

`Ethers.Transaction.to_rpc_map/1` now emits access list entries as objects, as the JSON-RPC spec
requires, and EIP-7702 authorization `r` and `s` as quantities. This affects custom RPC client
adapters and custom `Ethers.Signer` implementations built on `to_rpc_map/1` (like
`Ethers.Signer.JsonRPC`). The `:access_list` override format is unchanged.

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

`Ethers.Transaction.to_rpc_map/1` raises `ArgumentError` instead of `FunctionClauseError` for
values it cannot encode, including storage keys and blob versioned hashes that are not 32-byte
binaries.

#### Unregistered transaction types return `Ethers.Transaction.Unknown`

`Ethers.get_transaction/2` (also in `Ethers.batch/2`), `Ethers.Transaction.from_rpc_map/1` and
`Ethers.Transaction.decode/1` return an `Ethers.Transaction.Unknown` for a transaction type that is
not registered, like OP-stack deposit transactions (type `0x7e`). It keeps the transaction
undecoded: the JSON-RPC object in `rpc_map` (and its block metadata in `metadata`), or the bytes
after the type byte in `raw_payload`. `Ethers.Transaction.encode/1` and `transaction_hash/2` work
on one with `raw_payload` and raise `ArgumentError` on one with only `rpc_map`;
`to_rpc_map/1` raises for both.

`{:error, :unsupported_type}` is no longer returned: a `type` that is not a hex quantity now
returns `{:error, :invalid_type}`. `decode/1` no longer returns
`{:error, :unsupported_transaction_type}` for an unregistered type byte, only for a `0x00` type
byte (legacy transactions have no type byte).

```elixir
# Before (0.8.x)
{:error, :unsupported_type} = Ethers.get_transaction(deposit_tx_hash)

# After (1.0.0)
{:ok, %Ethers.Transaction.Unknown{type_id: 0x7E, rpc_map: rpc_map}} =
  Ethers.get_transaction(deposit_tx_hash)

rpc_map["from"]
#=> "0xdeaddeaddeaddeaddeaddeaddeaddeaddead0001"

{:ok, %Ethers.Transaction.Unknown{type_id: 0x7E, raw_payload: raw_payload}} =
  Ethers.Transaction.decode(raw_deposit_tx)
```

### Transaction Validation

#### Missing required fields return an error

Transaction `new/1` (and so `Ethers.Transaction.new/1` and `Ethers.Transaction.from_rpc_map/1`)
returns `{:error, :missing_<field>}` for a missing or `nil` required field. In 0.8.x a missing key
raised `KeyError` and `nil` returned `{:error, :expected_non_neg_integer_value}`.
`Ethers.Transaction.Legacy` no longer requires `chain_id` (pre-EIP-155 transactions).

```elixir
# Before (0.8.x)
Ethers.Transaction.new(%{type: Ethers.Transaction.Eip1559, nonce: 1})
#=> ** (KeyError) key :chain_id not found

# After (1.0.0)
Ethers.Transaction.new(%{type: Ethers.Transaction.Eip1559, nonce: 1})
#=> {:error, :missing_chain_id}
```

| Error | Returned by |
| --- | --- |
| `:missing_chain_id` | all types except `Legacy` |
| `:missing_nonce`, `:missing_gas` | all types |
| `:missing_gas_price` | `Legacy`, `Eip2930` |
| `:missing_max_fee_per_gas`, `:missing_max_priority_fee_per_gas` | `Eip1559`, `Eip4844`, `Eip7702` |
| `:missing_max_fee_per_blob_gas` | `Eip4844` |

#### Stricter validation in `new/1`

Transaction `new/1` now rejects transactions it used to build:

- `Ethers.Transaction.Eip4844` requires `to` and at least one 32-byte blob versioned hash.
- `Ethers.Transaction.Eip1559` validates `to` like the other types (`0x`-prefixed hex or `nil`).
- Access lists must be `[[<<address::binary-20>>, [<<storage_key::binary-32>>, ...]], ...]`,
  the form `Ethers.create_access_list/2` returns.
- EIP-7702 authorizations need a `signature_y_parity` of `0` or `1` and a `chain_id` below
  `2**256` (also enforced by `Ethers.Authorization.new/1`), and return the
  `Ethers.Authorization.new/1` errors otherwise.

```elixir
address = "0x07a6e955ba4345bae83ac2a6faa771fddd8a2011"

# Before (0.8.x)
Ethers.Transaction.new(%{type: Ethers.Transaction.Eip2930, access_list: [[address, []]], ...})
#=> {:ok, %Ethers.Transaction.Eip2930{...}}

# After (1.0.0)
Ethers.Transaction.new(%{type: Ethers.Transaction.Eip2930, access_list: [[address, []]], ...})
#=> {:error, :invalid_access_list}

access_list = [[Ethers.Utils.decode_address!(address), []]]
Ethers.Transaction.new(%{type: Ethers.Transaction.Eip2930, access_list: access_list, ...})
#=> {:ok, %Ethers.Transaction.Eip2930{...}}
```

| Error | Returned by | 0.8.x |
| --- | --- | --- |
| `:missing_to_address` | `Eip4844` | `{:ok, transaction}` with `to: nil` |
| `:empty_blob_versioned_hashes` | `Eip4844` | `{:ok, transaction}` without blobs |
| `:invalid_blob_versioned_hashes` | `Eip4844` | `{:ok, transaction}` |
| `:invalid_address`, `:invalid_address_length` | `Eip1559` | `{:ok, transaction}` |
| `:invalid_access_list` | `Eip2930`, `Eip1559`, `Eip4844`, `Eip7702` | `{:ok, transaction}` |
| `:invalid_signature_y_parity` | `Eip7702` | `{:ok, transaction}` |
| `:chain_id_out_of_range` | `Eip7702`, `Ethers.Authorization.new/1` | `{:ok, transaction}`, `{:ok, authorization}` |

### Transaction Decoding and Sender Recovery

#### `Signed.from_address/1` returns `{:ok, address}`

`Ethers.Transaction.Signed.from_address/1` returns `{:ok, address}` on success instead of the
bare address, matching its typespec and the rest of the API. Errors are still returned as
`{:error, reason}`.

```elixir
# Before (0.8.x)
address = Ethers.Transaction.Signed.from_address(signed_tx)

# After (1.0.0)
{:ok, address} = Ethers.Transaction.Signed.from_address(signed_tx)
```

#### `decode/1` returns errors instead of raising

`Ethers.Transaction.decode/1` no longer raises on malformed input. It returns `{:error, reason}`
with one of `:invalid_rlp`, `:unsupported_transaction_type`, `:transaction_decode_failed`,
`:invalid_address`, `:signature_decode_failed` or `:authorization_decode_failed`, so code that
rescued exceptions must match on the tuple instead.

Decoding is also stricter: a first byte in `0x00..0x7f` that is not a registered transaction type
is no longer decoded as a legacy transaction (it returns an `Ethers.Transaction.Unknown`, see
above, or `:unsupported_transaction_type` for `0x00`), and access list addresses (20 bytes),
storage keys (32 bytes) and blob versioned hashes (32 bytes) of the wrong size are rejected.

```elixir
# Before (0.8.x)
try do
  {:ok, transaction} = Ethers.Transaction.decode(raw_tx)
  transaction
rescue
  _error -> nil
end

# After (1.0.0)
case Ethers.Transaction.decode(raw_tx) do
  {:ok, transaction} -> transaction
  {:error, _reason} -> nil
end
```

#### Unsigned EIP-155 legacy transactions decode as unsigned

An unsigned legacy transaction with a chain id (encoded as `rlp([..., chain_id, 0, 0])`, as
`Ethers.Transaction.encode/1` produces) now decodes to the unsigned `Ethers.Transaction.Legacy`
struct with `chain_id` set, instead of an `Ethers.Transaction.Signed` with an empty signature and
`chain_id: nil`.

```elixir
# Before (0.8.x)
{:ok, %Ethers.Transaction.Signed{payload: %Ethers.Transaction.Legacy{chain_id: nil}}} =
  Ethers.Transaction.decode(unsigned_legacy_tx)

# After (1.0.0)
{:ok, %Ethers.Transaction.Legacy{chain_id: 1}} = Ethers.Transaction.decode(unsigned_legacy_tx)
```

#### Out-of-range recovery ids return an error

`Ethers.Transaction.Signed.from_address/1` returns `{:error, :invalid_recovery_id}` when the
signature's v / y-parity gives a recovery id other than 0 or 1. A negative one (a legacy `v` below
27) used to raise.

```elixir
# Before (0.8.x)
Ethers.Transaction.Signed.from_address(legacy_tx_with_v_1)
#=> ** (ArgumentError) argument error

# After (1.0.0)
Ethers.Transaction.Signed.from_address(legacy_tx_with_v_1)
#=> {:error, :invalid_recovery_id}
```

### Checksummed Addresses

#### Returned addresses are EIP-55 checksummed

Every address the library returns is now [EIP-55](https://eips.ethereum.org/EIPS/eip-55)
checksummed. These return values used to keep the casing of the node (usually lowercase) or the
casing they were configured with:

- `address` of `Ethers.Event`, as returned by `Ethers.get_logs/2` (also `:get_logs` in
  `Ethers.batch/2`), `Ethers.Event.decode/2`, `Ethers.Event.find_and_decode/2` and
  `Ethers.CombinedEventFilter.decode_logs/2`
- `Ethers.deployed_address/2` (also `:deployed_address` in `Ethers.batch/2`)
- `accounts/1` of `Ethers.Signer.JsonRPC`
- The `default_address` of contract modules: `__default_address__/0` and the `default_address`
  of the `Ethers.TxData`, `Ethers.EventFilter` and `Ethers.CombinedEventFilter` structs they
  build

Other returned addresses (ABI-decoded values, transaction `to`, recovered signers, ...) were
already checksummed. Raw RPC values (`topics_raw`, `data_raw`, the `logs` of an `Ethers.Receipt`)
are unchanged, and addresses are still accepted in any casing.

```elixir
{:ok, address} = Ethers.deployed_address(tx_hash)

# Before (0.8.x)
address
#=> "0x1000bf6a479f320ead074411a4b0e7944ea8c9c1"

# After (1.0.0)
address
#=> "0x1000BF6a479F320EAD074411A4B0e7944Ea8C9C1"
```

Compare addresses of unknown casing on their checksummed or decoded form, not as strings:

```elixir
address == Ethers.Utils.to_checksum_address(other_address)
Ethers.Utils.decode_address!(address) == Ethers.Utils.decode_address!(other_address)
```

### Transaction Receipts

#### `get_transaction_receipt/2` returns an `Ethers.Receipt` struct

`Ethers.get_transaction_receipt/2`, `Ethers.get_transaction_receipt!/2` and the
`:get_transaction_receipt` action of `Ethers.batch/2` return an `Ethers.Receipt` struct instead of
the node's JSON map: quantities are integers, `status` is `:success` or `:failure` and addresses are
checksummed. Logs are kept as returned by the node, decode them with
`Ethers.Receipt.decode_logs/2`. Members the library does not decode, such as chain specific
members, are kept undecoded in `extra`. A malformed receipt returns
`{:error, {:invalid_receipt_member, member}}`.

```elixir
{:ok, receipt} = Ethers.get_transaction_receipt(tx_hash)

# Before (0.8.x)
%{"status" => "0x1", "gasUsed" => gas_used_hex, "contractAddress" => contract_address} = receipt
gas_used = Ethers.Utils.hex_to_integer!(gas_used_hex)
l1_fee = receipt["l1Fee"]

# After (1.0.0)
%Ethers.Receipt{status: :success, gas_used: gas_used, contract_address: contract_address} = receipt
l1_fee = receipt.extra["l1Fee"]
events = Ethers.Receipt.decode_logs(receipt, MyContract.EventFilters)
```

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