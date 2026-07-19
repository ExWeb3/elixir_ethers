# Sign-In with Ethereum

[EIP-4361](https://eips.ethereum.org/EIPS/eip-4361) (Sign-In with Ethereum, or SIWE) is the
standard way for a wallet to authenticate to an off-chain service. The backend issues a
single-use nonce, the wallet signs a structured plaintext message containing it, and the
backend verifies the returned message and signature to establish a session — no passwords, no
OAuth provider, the Ethereum account *is* the identity.

Ethers models the message with `Ethers.Siwe.Message` and covers the whole lifecycle in
`Ethers.Siwe`: building (`new/1`), rendering (`to_message/1`), parsing (`parse/1`), stateless
validation (`validate/2`) and full verification including the signature (`verify/3`).

## The flow

1. The client asks your backend for a nonce. The backend generates one with
   `Ethers.Siwe.generate_nonce/0` and stores it in the session.
2. The client builds an EIP-4361 message containing that nonce and asks the wallet to sign it
   with `personal_sign`.
3. The client posts the message and signature back. The backend calls `Ethers.Siwe.verify/3`,
   which parses the message, validates its fields (validity window, expected domain and nonce)
   and verifies the signature — including EIP-1271 and ERC-6492 smart-contract wallets.
4. On success, the backend trusts `message.address` and stores it in the session.

## Phoenix example

Issue the nonce:

```elixir
def nonce(conn, _params) do
  nonce = Ethers.Siwe.generate_nonce()

  conn
  |> put_session(:siwe_nonce, nonce)
  |> json(%{nonce: nonce})
end
```

Verify the callback:

```elixir
def verify(conn, %{"message" => raw_message, "signature" => signature}) do
  case Ethers.Siwe.verify(raw_message, signature,
         domain: "example.com",
         nonce: get_session(conn, :siwe_nonce)
       ) do
    {:ok, message} ->
      conn
      |> delete_session(:siwe_nonce)
      |> put_session(:address, message.address)
      |> json(%{ok: true, address: message.address})

    {:error, reason} ->
      conn
      |> put_status(401)
      |> json(%{error: inspect(reason)})
  end
end
```

`verify/3` needs no RPC round-trip for regular (EOA) wallets. To also support
smart-contract wallets (Safe, Coinbase Smart Wallet, ERC-4337 accounts — deployed or
counterfactual), pass `rpc_opts:` so the ERC-6492 universal validator can be called on the
chain the message is bound to:

```elixir
Ethers.Siwe.verify(raw_message, signature,
  domain: "example.com",
  nonce: get_session(conn, :siwe_nonce),
  rpc_opts: [url: "https://eth.llamarpc.com"]
)
```

## Building a message server-side

If your backend constructs the message itself (instead of a JS client library):

```elixir
message =
  Ethers.Siwe.new!(
    domain: "example.com",
    address: user_address,
    statement: "Sign in to Example",
    uri: "https://example.com",
    chain_id: 1,
    nonce: Ethers.Siwe.generate_nonce(),
    expiration_time: DateTime.add(DateTime.utc_now(), 300)
  )

raw = Ethers.Siwe.to_message(message)
# => "example.com wants you to sign in with your Ethereum account:\n0x..."
```

The rendered string is what the wallet signs. `issued_at` defaults to the current time and
`version` to `"1"`.

## Validating without verifying

`Ethers.Siwe.validate/2` performs only the stateless field checks — validity window
(`expiration_time` is an exclusive bound, `not_before` inclusive), expected `domain:`,
`nonce:`, `address:` and `scheme:` — without touching the signature. This is useful in tests
(inject `time:`) or when the signature was already checked elsewhere:

```elixir
:ok =
  Ethers.Siwe.validate(message,
    domain: "example.com",
    nonce: session_nonce,
    time: DateTime.utc_now()
  )
```

## Security notes

- **Always check the nonce** against the one your backend issued and invalidate it after use —
  it is the replay protection.
- **Always pin the domain** to your origin. A message signed for another site must not
  authenticate here.
- Set a short `expiration_time` when you build messages server-side.
- `parse/1` is strict: field order, EIP-55 checksummed addresses, RFC 3339 timestamps and
  RFC 3986 domain/URIs are enforced, and a parsed message re-renders byte-for-byte identical —
  so verifying the re-rendered message is safe.
