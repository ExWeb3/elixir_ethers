defmodule Ethers.PersonalMessage do
  @moduledoc """
  [EIP-191](https://eips.ethereum.org/EIPS/eip-191) personal message utilities
  (the `personal_sign` scheme, version byte `0x45`).

  Personal messages are what wallets sign when an app requests `personal_sign` — wallet
  login flows, off-chain agreements, API authentication and the like. The signed payload
  is not the raw message but its EIP-191 hash:

      keccak256("\\x19Ethereum Signed Message:\\n" <> Integer.to_string(byte_size(message)) <> message)

  This module provides the pure primitives: hashing (`hash/1`), signer recovery
  (`recover/2`) and signature verification (`verify/3`). To produce a signature use
  `Ethers.personal_sign/2`, which routes through the configured `Ethers.Signer`.

  ## Message encoding

  The message is always treated as raw bytes, exactly as given. In particular a
  `"0x..."`-prefixed string is signed as the literal text, **not** hex-decoded. If you
  want to sign pre-encoded bytes, decode them yourself first (e.g. with
  `Ethers.Utils.hex_decode!/1`).

  ## Verification scope

  Recovery and verification here are `ecrecover`-based and therefore work for
  externally-owned accounts (EOAs) only. Signatures from smart-contract wallets
  (ERC-1271/ERC-6492) cannot be verified this way and need the RPC-backed
  `Ethers.Signature` module.
  """

  alias Ethers.ExecutionError
  alias Ethers.Utils

  @prefix "\x19Ethereum Signed Message:\n"

  @doc """
  Calculates the EIP-191 (version `0x45`) hash of a personal message.

  The message is treated as raw bytes. Returns the 32-byte digest.

  ## Examples

      iex> Ethers.PersonalMessage.hash("Hello world") |> Ethers.Utils.hex_encode()
      "0x8144a6fa26be252b86456491fbcd43c1de7e022241845ffea1c3df066f7cfede"
  """
  @spec hash(binary()) :: <<_::256>>
  def hash(message) when is_binary(message) do
    Ethers.keccak_module().hash_256(@prefix <> Integer.to_string(byte_size(message)) <> message)
  end

  @doc """
  Recovers the address which signed a personal message.

  `signature` may be a `0x`-prefixed hex string or a raw 65-byte binary (`r ‖ s ‖ v`).
  Both the message-signature convention (`v ∈ {27, 28}`) and raw parity (`v ∈ {0, 1}`)
  are accepted.

  ## Returns

  - `{:ok, address}` with the checksummed signer address on success.
  - `{:error, reason}` if the signature is malformed or recovery fails.

  ## Examples

      iex> signature =
      ...>   "0x15a3fe3974ebe469b00e67ad67bb3860ad3fc3d739287cdbc4ba558ce7130bee" <>
      ...>   "205e5e38d6ef156f1ff6a4df17bfa72a1e61c429f92613f3efbc58394d00c9891b"
      iex> Ethers.PersonalMessage.recover("Hello world", signature)
      {:ok, "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"}
  """
  @spec recover(binary(), binary()) :: {:ok, Ethers.Types.t_address()} | {:error, term()}
  def recover(message, signature) when is_binary(message) and is_binary(signature) do
    with {:ok, <<r::binary-size(32), s::binary-size(32), v::integer>>} <-
           normalize_signature(signature),
         {:ok, recovery_id} <- normalize_recovery_id(v),
         {:ok, public_key} <-
           Ethers.secp256k1_module().recover(hash(message), r, s, recovery_id) do
      {:ok, Utils.public_key_to_address(public_key)}
    end
  end

  @doc """
  Same as `recover/2` but raises on error.
  """
  @spec recover!(binary(), binary()) :: Ethers.Types.t_address() | no_return()
  def recover!(message, signature) do
    case recover(message, signature) do
      {:ok, address} -> address
      {:error, reason} -> raise ExecutionError, reason
    end
  end

  @doc """
  Checks whether `signature` over `message` was produced by `expected_address`.

  Recovers the signer via `recover/2` and compares it to `expected_address`. The
  comparison is done on the decoded 20-byte addresses, so checksum/case differences are
  ignored. Returns `false` (does not raise) when the signature is malformed.

  EOA-only — for smart-contract wallets use the RPC-backed `Ethers.Signature` module.

  ## Examples

      iex> signature =
      ...>   "0x15a3fe3974ebe469b00e67ad67bb3860ad3fc3d739287cdbc4ba558ce7130bee" <>
      ...>   "205e5e38d6ef156f1ff6a4df17bfa72a1e61c429f92613f3efbc58394d00c9891b"
      iex> Ethers.PersonalMessage.verify("Hello world", signature, "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266")
      true
  """
  @spec verify(binary(), binary(), Ethers.Types.t_address()) :: boolean()
  def verify(message, signature, expected_address) do
    case recover(message, signature) do
      {:ok, recovered} ->
        Utils.decode_address!(recovered) == Utils.decode_address!(expected_address)

      {:error, _reason} ->
        false
    end
  end

  @spec normalize_signature(binary()) :: {:ok, <<_::520>>} | {:error, :invalid_signature}
  defp normalize_signature("0x" <> _ = hex) do
    case Utils.hex_decode(hex) do
      {:ok, binary} -> normalize_signature(binary)
      :error -> {:error, :invalid_signature}
    end
  end

  defp normalize_signature(<<_::binary-size(65)>> = binary), do: {:ok, binary}
  defp normalize_signature(binary) when is_binary(binary), do: {:error, :invalid_signature}

  # Accepts both the message-signature convention (`v ∈ {27, 28}`) and raw parity
  # (`v ∈ {0, 1}`) that some signers/providers return, mapping both to a `0..1` recovery id.
  @spec normalize_recovery_id(byte()) :: {:ok, 0..1} | {:error, :invalid_signature}
  defp normalize_recovery_id(v) when v in [0, 27], do: {:ok, 0}
  defp normalize_recovery_id(v) when v in [1, 28], do: {:ok, 1}
  defp normalize_recovery_id(_v), do: {:error, :invalid_signature}
end
