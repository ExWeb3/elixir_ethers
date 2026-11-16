# Signing and Verification

This guide covers signers, signing messages and typed data, and verifying signatures. Transactions
are signed the same way: see [Transactions](transactions.md#who-signs).

## Signers

A signer is a module that implements the `Ethers.Signer` behaviour. Two are built in:

- `Ethers.Signer.Local` signs with a private key inside your application. It needs the optional
  `ex_secp256k1` dependency.
- `Ethers.Signer.JsonRPC` asks a node or a signing service, such as
  [web3signer](https://github.com/Consensys/web3signer), to sign over JSON-RPC.

Pass the signer with each call:

```elixir
Ethers.personal_sign("Hello world",
  signer: Ethers.Signer.Local,
  signer_opts: [private_key: System.fetch_env!("ETH_PRIVATE_KEY")]
)
```

Or set a default once:

```elixir
# config/runtime.exs
config :ethers,
  default_signer: Ethers.Signer.Local,
  default_signer_opts: [private_key: System.fetch_env!("ETH_PRIVATE_KEY")]
```

`Ethers.Signer.JsonRPC` takes the endpoint of the signing service in its options:

```elixir
config :ethers,
  default_signer: Ethers.Signer.JsonRPC,
  default_signer_opts: [url: "http://localhost:9000"]
```

> #### Private keys {: .warning}
>
> Keep private keys out of source control and out of compile-time configuration.
> `Ethers.Signer.Local` has no protection for the key beyond what your application provides. In
> production, prefer a signer that keeps the key outside your application.

The rest of this guide assumes a default signer is configured.

### Writing a signer

To sign with a KMS, an HSM or a wallet service, implement the `Ethers.Signer` behaviour. Two
callbacks are required:

- `c:Ethers.Signer.sign_transaction/2` returns the signed transaction as a hex string
- `c:Ethers.Signer.accounts/1` lists the addresses the signer can sign for

Three are optional, and a signer without them does not support that kind of signature:
`c:Ethers.Signer.personal_sign/2`, `c:Ethers.Signer.sign_typed_data/2` and
`c:Ethers.Signer.sign_authorization/2`.

## Messages

`Ethers.personal_sign/2` signs a message with the [EIP-191](https://eips.ethereum.org/EIPS/eip-191)
`personal_sign` scheme, the one wallets use for "Sign message" prompts.

```elixir
{:ok, signature} = Ethers.personal_sign("Hello world")
#=> {:ok, "0x15a3fe39...4d00c9891b"}
```

The message is signed as the bytes you give. A string that starts with `"0x"` is signed as that
text and is not decoded.

`Ethers.PersonalMessage` recovers the signer and checks a signature without any network request:

```elixir
Ethers.PersonalMessage.recover("Hello world", signature)
#=> {:ok, "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"}

Ethers.PersonalMessage.verify(
  "Hello world",
  signature,
  "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
)
#=> true
```

## Typed data

`Ethers.sign_typed_data/2` signs [EIP-712](https://eips.ethereum.org/EIPS/eip-712) typed structured
data built with `Ethers.TypedData`.

```elixir
typed_data =
  Ethers.TypedData.new!(
    primary_type: "Mail",
    types: %{
      "Mail" => [
        %{name: "to", type: "address"},
        %{name: "contents", type: "string"}
      ]
    },
    domain: [name: "Ether Mail", version: "1", chain_id: 1],
    message: %{
      "to" => "0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB",
      "contents" => "Hello, Bob!"
    }
  )

{:ok, signature} = Ethers.sign_typed_data(typed_data)

Ethers.TypedData.recover_signer(typed_data, signature)
#=> "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
```

The [EIP-712 guide](eip-712.md) covers nested types, hashing, and declaring typed data as Elixir
structs.

## Verifying signatures

> #### Recovering is not enough {: .warning}
>
> Recovering the signer only works for accounts controlled by a private key. Smart-contract
> wallets, such as Safe and ERC-4337 or EIP-7702 accounts, cannot produce signatures that recover
> to their address. A backend that only recovers rejects those users.

`Ethers.Signature` verifies a signature from any account: key-pair accounts, smart-contract wallets
([ERC-1271](https://eips.ethereum.org/EIPS/eip-1271)) and wallets that are not deployed yet
([ERC-6492](https://eips.ethereum.org/EIPS/eip-6492)).

```elixir
account = "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"

Ethers.Signature.verify_message("Hello world", signature, account)
#=> {:ok, true}

Ethers.Signature.verify_typed_data(typed_data, signature, account)
#=> {:ok, true}
```

`Ethers.Signature.verify_hash/4` does the same for a 32-byte digest.

A signature that recovers to the account is accepted locally, without a network request. Otherwise
one `eth_call` asks the chain. The result is `{:ok, true}` or `{:ok, false}`, and `{:error, reason}`
is reserved for failures to reach the node. These functions have no `!` variants, so that an
invalid signature is never confused with a network failure.

## Sign-In with Ethereum

For wallet login, `Ethers.Siwe` implements [EIP-4361](https://eips.ethereum.org/EIPS/eip-4361):
building, parsing, validating and verifying messages, including signatures of smart-contract
wallets. The [Sign-In with Ethereum guide](siwe.md) walks through a Phoenix example.

## EIP-7702 authorizations

`Ethers.sign_authorization/2` signs an authorization that delegates an account to contract code.
See [Transactions](transactions.md#eip-7702-authorizations).
