defmodule Ethers.Authorization.Signed do
  @moduledoc """
  A signed [EIP-7702](https://eips.ethereum.org/EIPS/eip-7702) authorization.

  Wraps an `Ethers.Authorization` together with its secp256k1 signature. Signed
  authorizations are what goes into the `authorization_list` of a type-4 transaction
  (`Ethers.Transaction.Eip7702`) and serialize to the on-wire tuple
  `[chain_id, address, nonce, y_parity, r, s]`.

  Produce one with `Ethers.sign_authorization/2`. Use `recover_authority/1` to get the
  address of the account that signed (the *authority* — the EOA whose code will be set).
  """

  alias Ethers.Authorization
  alias Ethers.Utils

  @secp256k1n 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141

  @enforce_keys [:authorization, :signature_y_parity, :signature_r, :signature_s]
  defstruct [:authorization, :signature_y_parity, :signature_r, :signature_s]

  @typedoc """
  A signed EIP-7702 authorization incorporating the following fields:
  - `authorization` - the signed `Ethers.Authorization` payload
  - `signature_y_parity` - signature recovery bit (`0` or `1`)
  - `signature_r` - signature `r` value (big-endian binary)
  - `signature_s` - signature `s` value (big-endian binary)
  """
  @type t :: %__MODULE__{
          authorization: Authorization.t(),
          signature_y_parity: 0 | 1,
          signature_r: binary(),
          signature_s: binary()
        }

  @doc """
  Recovers the authority (signer) address of a signed authorization.

  Enforces the EIP-2 low-`s` rule that EIP-7702 mandates: a signature with
  `s > secp256k1n / 2` returns `{:error, :invalid_signature_s}` because the chain would
  silently skip such an authorization.

  ## Returns
  - `{:ok, address}` with the checksummed authority address on success.
  - `{:error, reason}` if the signature is malformed or recovery fails.
  """
  @spec recover_authority(t()) :: {:ok, Ethers.Types.t_address()} | {:error, term()}
  def recover_authority(%__MODULE__{authorization: %Authorization{} = authorization} = signed) do
    digest = Authorization.hash(authorization)

    with {:ok, recovery_id} <- normalize_recovery_id(signed.signature_y_parity),
         :ok <- validate_low_s(signed.signature_s),
         {:ok, public_key} <-
           Ethers.secp256k1_module().recover(
             digest,
             pad32(signed.signature_r),
             pad32(signed.signature_s),
             recovery_id
           ) do
      {:ok, Utils.public_key_to_address(public_key)}
    end
  end

  @doc false
  @spec from_rlp_list([binary()]) :: {:ok, t()} | {:error, :authorization_decode_failed}
  def from_rlp_list([chain_id, address, nonce, y_parity, r, s]) do
    {:ok,
     %__MODULE__{
       authorization: %Authorization{
         chain_id: :binary.decode_unsigned(chain_id),
         address: Utils.encode_address!(address),
         nonce: :binary.decode_unsigned(nonce)
       },
       signature_y_parity: :binary.decode_unsigned(y_parity),
       signature_r: r,
       signature_s: s
     }}
  end

  def from_rlp_list(_rlp_list), do: {:error, :authorization_decode_failed}

  @doc false
  @spec to_rlp_list(t()) :: [binary() | non_neg_integer()]
  def to_rlp_list(%__MODULE__{} = signed) do
    Authorization.to_rlp_list(signed.authorization) ++
      [
        signed.signature_y_parity,
        Utils.remove_leading_zeros(signed.signature_r),
        Utils.remove_leading_zeros(signed.signature_s)
      ]
  end

  defp validate_low_s(s) when is_binary(s) do
    if :binary.decode_unsigned(s) > div(@secp256k1n, 2) do
      {:error, :invalid_signature_s}
    else
      :ok
    end
  end

  defp normalize_recovery_id(v) when v in [0, 27], do: {:ok, 0}
  defp normalize_recovery_id(v) when v in [1, 28], do: {:ok, 1}
  defp normalize_recovery_id(_v), do: {:error, :invalid_signature}

  defp pad32(bin) when byte_size(bin) >= 32, do: bin
  defp pad32(bin), do: <<0::size((32 - byte_size(bin)) * 8), bin::binary>>
end
