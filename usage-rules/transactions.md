# Transactions

- Send a transaction by piping a contract function into `Ethers.send_transaction/2`. The `:from`
  option is required. Without it the result is `{:error, :no_from_address}`.
- To send ether without calling a contract, pass a map:
  `Ethers.send_transaction(%{value: Ethers.Utils.to_wei(1)}, from: sender, to: recipient)`.
- Do not set the nonce, gas limit, chain id or fees unless there is a reason to. Ethers fetches
  them. Fees of EIP-1559 transactions, the default type, come from `Ethers.estimate_fees/1`.

```elixir
{:ok, tx_hash} =
  MyApp.Token.transfer(recipient, 1000) |> Ethers.send_transaction(from: sender)
```

## Signers

- The signer is taken from the `:signer` and `:signer_opts` options, then from the
  `:default_signer` and `:default_signer_opts` application config. With neither, the transaction is
  sent with `eth_sendTransaction` and the node must hold the key of the sender. Public RPC
  endpoints do not, so configure a signer when using one.
- `Ethers.Signer.Local` signs with a private key and needs the optional `ex_secp256k1` dependency.
  `Ethers.Signer.JsonRPC` delegates to a node or a signing service.
- Never write a private key in source code or in compile-time configuration. Read it at runtime,
  for example with `System.fetch_env!/1` in `config/runtime.exs`.
- When the private key does not belong to the `:from` address, the result is
  `{:error, :wrong_key}`.

```elixir
# config/runtime.exs
config :ethers,
  default_signer: Ethers.Signer.Local,
  default_signer_opts: [private_key: System.fetch_env!("ETH_PRIVATE_KEY")]
```

## Receipts

- `Ethers.send_transaction/2` returns the transaction hash as soon as the node accepts the
  transaction. That does not mean it succeeded, or that it is included in a block yet.
- `Ethers.get_transaction_receipt/2` returns `{:error, :transaction_receipt_not_found}` until the
  transaction is included. Poll for it. Ethers has no function that waits.
- Check `receipt.status`. It is `:success` or `:failure`. A reverted transaction still has a
  receipt.
- The receipt is an `Ethers.Receipt` struct with decoded fields. Decode its logs with
  `Ethers.Receipt.decode_logs/2`.

## Transaction types

- Select the type with the `:type` option: `Ethers.Transaction.Legacy`,
  `Ethers.Transaction.Eip2930`, `Ethers.Transaction.Eip1559` (the default),
  `Ethers.Transaction.Eip4844` or `Ethers.Transaction.Eip7702`.
- EIP-4844 transactions cannot be broadcast with Ethers, because it does not build blob sidecars.
- To sign without sending, use `Ethers.sign_transaction/2`. Decode a raw transaction with
  `Ethers.Transaction.decode/1`.

## EIP-7702

- Sign an authorization with `Ethers.sign_authorization/2` and pass it in the
  `:authorization_list` option of a `type: Ethers.Transaction.Eip7702` transaction.
- Pass `executor: :self` to `Ethers.sign_authorization/2` when the authorizing account sends the
  transaction itself. Otherwise the authorization nonce is off by one.
- An authorization with a wrong nonce is skipped on chain without failing the transaction. Confirm
  the delegation with `Ethers.get_delegation/2`.
- `Ethers.Signer.JsonRPC` cannot sign authorizations.
