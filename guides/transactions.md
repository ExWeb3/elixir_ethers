# Transactions

This guide covers sending transactions, waiting for them, paying for them, and the transaction
types Ethers supports.

The examples use a contract module named `MyToken` (see [Contracts](contracts.md)) and these
values:

```elixir
sender = "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
recipient = "0x70997970C51812dc3A010C7d01b50e0d17dc79C8"
```

## Sending a transaction

Pipe a contract function into `Ethers.send_transaction/2`. It returns the transaction hash.

```elixir
{:ok, tx_hash} =
  MyToken.transfer(recipient, 1000) |> Ethers.send_transaction(from: sender)
```

`:from` is required. Everything else has a default: the nonce, the gas limit, the chain id and the
fees are fetched from the network when you do not pass them.

To send ether without calling a contract, pass a map and a `:to` address. Values are in wei.

```elixir
Ethers.send_transaction(%{value: Ethers.Utils.to_wei(1)}, from: sender, to: recipient)
```

To send ether along with a call to a payable function, add `:value` to the options.

## Who signs

A transaction must be signed by the `:from` account. Ethers looks for a signer in this order:

1. the `:signer` and `:signer_opts` options of the call
2. the `:default_signer` and `:default_signer_opts` application config
3. no signer: the transaction is sent with `eth_sendTransaction` and the node signs it

```elixir
MyToken.transfer(recipient, 1000)
|> Ethers.send_transaction(
  from: sender,
  signer: Ethers.Signer.Local,
  signer_opts: [private_key: System.fetch_env!("ETH_PRIVATE_KEY")]
)
```

> #### Public endpoints cannot sign {: .warning}
>
> The third option only works with a node that holds the key of the sender, such as a local
> development node. Public RPC endpoints do not hold your keys. With them you need a signer.

[Signers](signing.md#signers) describes the built-in signers and how to write your own.

## Waiting for the receipt

The hash is returned as soon as the node accepts the transaction, before it is included in a
block. `Ethers.get_transaction_receipt/2` returns `{:error, :transaction_receipt_not_found}` until
then, so poll for it:

```elixir
defmodule MyApp.Chain do
  def wait_for_receipt(tx_hash, attempts \\ 30) do
    case Ethers.get_transaction_receipt(tx_hash) do
      {:ok, receipt} ->
        {:ok, receipt}

      {:error, :transaction_receipt_not_found} when attempts > 0 ->
        Process.sleep(1_000)
        wait_for_receipt(tx_hash, attempts - 1)

      {:error, reason} ->
        {:error, reason}
    end
  end
end
```

The receipt is an `Ethers.Receipt` struct with decoded fields:

```elixir
{:ok, receipt} = MyApp.Chain.wait_for_receipt(tx_hash)

receipt.status
#=> :success

receipt.gas_used
#=> 28822

receipt.block_number
#=> 26425619
```

A transaction that was included but reverted has the status `:failure`, so always check it. The
logs of the receipt are decoded with `Ethers.Receipt.decode_logs/2`, see
[Events](events.md#events-of-a-transaction).

## Fees and gas

For EIP-1559 transactions, the default type, Ethers estimates the fees from recent blocks with
`Ethers.estimate_fees/1`:

```elixir
Ethers.estimate_fees()
#=> {:ok, %{max_fee_per_gas: 334398307, max_priority_fee_per_gas: 11098767}}

Ethers.estimate_fees(speed: :fast)
#=> {:ok, %{max_fee_per_gas: 1187792345, max_priority_fee_per_gas: 864547083}}
```

`:speed` is `:slow`, `:standard` (the default) or `:fast`. To set the fees yourself, pass
`:max_fee_per_gas` and `:max_priority_fee_per_gas` to `Ethers.send_transaction/2`.

When Ethers signs the transaction, the gas limit defaults to the result of `Ethers.estimate_gas/2`
plus a safety margin of 10%. When the node signs, the node fills it in. Pass `:gas` to set it
yourself. The margins are [configurable](configuration.md#gas-margins).

```elixir
MyToken.transfer(recipient, 1000) |> Ethers.estimate_gas(from: sender)
#=> {:ok, 51939}
```

> #### Gas limit cap {: .info}
>
> Since [EIP-7825](https://eips.ethereum.org/EIPS/eip-7825), Ethereum rejects transactions with a
> gas limit above 16,777,216. Ethers logs a warning for such a gas limit, and enforces a cap when
> `:max_transaction_gas` is [configured](configuration.md#max-transaction-gas-max_transaction_gas).

## Access lists

`Ethers.create_access_list/2` simulates a transaction and returns the addresses and storage slots
it touches. Passing the list back with the transaction can reduce its gas cost.

```elixir
transfer = MyToken.transfer(recipient, 1000)

{:ok, %{access_list: access_list}} = Ethers.create_access_list(transfer, from: sender)

Ethers.send_transaction(transfer, from: sender, access_list: access_list)
```

## Transaction types

The `:type` option of `Ethers.send_transaction/2` selects the transaction type.

| Type | Module | Notes |
| --- | --- | --- |
| 0 | `Ethers.Transaction.Legacy` | Priced with `:gas_price` |
| 1 | `Ethers.Transaction.Eip2930` | Legacy pricing with an access list |
| 2 | `Ethers.Transaction.Eip1559` | The default |
| 3 | `Ethers.Transaction.Eip4844` | Blob transactions, see the note below |
| 4 | `Ethers.Transaction.Eip7702` | Carries [authorizations](#eip-7702-authorizations) |

```elixir
Ethers.send_transaction(%{value: 1},
  from: sender,
  to: recipient,
  type: Ethers.Transaction.Legacy
)
```

> #### EIP-4844 {: .warning}
>
> Blob transactions can be built, signed and decoded, but not broadcast. Ethers does not build the
> blob sidecar, and nodes reject a blob transaction without one.

## EIP-7702 authorizations

An [EIP-7702](https://eips.ethereum.org/EIPS/eip-7702) authorization lets an externally owned
account delegate to contract code. Sign one with `Ethers.sign_authorization/2` and include it in a
type 4 transaction. The chain id and the nonce are fetched when you do not give them.

```elixir
account = "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
delegate = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"

# `executor: :self` because the account sends the transaction itself
{:ok, authorization} =
  Ethers.sign_authorization(%{address: delegate}, executor: :self)

{:ok, tx_hash} =
  Ethers.send_transaction(%{},
    from: account,
    to: account,
    type: Ethers.Transaction.Eip7702,
    authorization_list: [authorization]
  )

# Once the transaction is included
Ethers.get_delegation(account)
#=> {:ok, "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"}
```

> #### Check the delegation {: .warning}
>
> An authorization with a mismatched nonce does not fail the transaction. It is skipped silently
> on chain, so always confirm the result with `Ethers.get_delegation/2`.

`Ethers.Signer.JsonRPC` cannot sign authorizations, because there is no standard RPC method for it.
Use `Ethers.Signer.Local` or a custom signer.

## Signing without sending

`Ethers.sign_transaction/2` takes the same options as `Ethers.send_transaction/2` and returns the
signed transaction as a hex string, ready for `eth_sendRawTransaction`.

```elixir
{:ok, raw} =
  MyToken.transfer(recipient, 1000) |> Ethers.sign_transaction(from: sender)
#=> {:ok, "0x02f8b101822d8f843b9aca008445c71b6e827c..."}
```

`Ethers.Transaction.decode/1` turns it back into a struct, and
`Ethers.Transaction.Signed.from_address/1` recovers the sender:

```elixir
{:ok, signed} = Ethers.Transaction.decode(raw)
#=> {:ok, %Ethers.Transaction.Signed{payload: %Ethers.Transaction.Eip1559{...}, ...}}

Ethers.Transaction.Signed.from_address(signed)
#=> {:ok, "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"}
```

`Ethers.get_transaction/2` fetches a transaction by hash and returns the same struct.

A transaction of a type Ethers has no module for, such as an OP-stack deposit transaction, comes
back from both functions as an `Ethers.Transaction.Unknown` struct, which keeps the transaction
undecoded.
