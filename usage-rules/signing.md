# Signing and verification

- Signing functions take the signer from the `:signer` and `:signer_opts` options, then from the
  `:default_signer` and `:default_signer_opts` application config, and fall back to
  `Ethers.Signer.JsonRPC`.
- `Ethers.Signer.Local` needs the optional `ex_secp256k1` dependency. Add it to the project
  dependencies before using it.
- To sign with a KMS, an HSM or a wallet service, implement the `Ethers.Signer` behaviour instead
  of handling private keys in the application.

## Messages

- Sign a message with `Ethers.personal_sign/2` (EIP-191). The message is signed as the bytes given.
  A string that starts with `"0x"` is signed as text, it is not hex decoded.
- Signatures are `"0x"`-prefixed hex strings of 65 bytes.

## Typed data

- Build EIP-712 typed data with `Ethers.TypedData.new/1` or `Ethers.TypedData.new!/1`, and sign it
  with `Ethers.sign_typed_data/2`.

## Verification

- To verify a signature, use `Ethers.Signature.verify_message/4`,
  `Ethers.Signature.verify_typed_data/4` or `Ethers.Signature.verify_hash/4`. They work for
  key-pair accounts and for smart-contract wallets (ERC-1271, ERC-6492).
- These functions return `{:ok, true}` or `{:ok, false}`. `{:error, reason}` means the node could
  not be reached, not that the signature is invalid. They have no `!` variants.
- Do not verify by recovering the signer with `Ethers.PersonalMessage.recover/2` or
  `Ethers.TypedData.recover_signer/2` when users may sign with a smart-contract wallet. Recovery
  only works for key-pair accounts.

```elixir
case Ethers.Signature.verify_message(message, signature, address) do
  {:ok, true} -> :ok
  {:ok, false} -> {:error, :invalid_signature}
  {:error, reason} -> {:error, reason}
end
```

## Sign-In with Ethereum

- For wallet login use `Ethers.Siwe`. Generate the nonce with `Ethers.Siwe.generate_nonce/0`, store
  it in the session, and verify the message and signature with `Ethers.Siwe.verify/3`, passing the
  expected `:domain` and `:nonce`. Do not parse or validate EIP-4361 messages by hand.
