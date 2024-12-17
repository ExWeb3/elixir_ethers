defmodule Ethers.Signer.Local do
  @moduledoc """
  Local signer works with a private key.

  IMPORTANT: Please note that using this signer is discouraged in production
  environment since handling private keys in those environment can be challenging
  if you don't know what you are doing.

  ## Signer Options

  - `:private_key`: The private key to use for signing and calculating account address.
     Private key can either be in binary format (32 bytes) or it's hex encoded format with or
     without `0x` prefix.
  """

  @behaviour Ethers.Signer

  import Ethers, only: [secp256k1_module: 0, keccak_module: 0]

  alias Ethers.Transaction
  alias Ethers.Transaction.SignedTransaction
  alias Ethers.Utils

  if not Code.ensure_loaded?(secp256k1_module()) do
    @impl true
    def sign_transaction(_tx, _opts), do: {:error, :secp256k1_module_not_loaded}

    @impl true
    def accounts(_opts), do: {:error, :secp256k1_module_not_loaded}
  end

  @impl true
  def sign_transaction(transaction, opts) do
    with {:ok, private_key} <- private_key(opts),
         :ok <- validate_private_key(private_key, Keyword.get(opts, :from)),
         encoded = Transaction.encode(transaction, :hash),
         sign_hash = keccak_module().hash_256(encoded),
         {:ok, {r, s, recovery_id}} <- secp256k1_module().sign(sign_hash, private_key) do
      signed_transaction =
        %SignedTransaction{
          transaction: transaction,
          signature_r: r,
          signature_s: s,
          signature_y_parity_or_v:
            SignedTransaction.calculate_y_parity_or_v(transaction, recovery_id)
        }

      encoded_signed_transaction = Transaction.encode(signed_transaction)

      {:ok, Utils.hex_encode(encoded_signed_transaction)}
    end
  end

  @impl true
  def accounts(opts) do
    with {:ok, private_key} <- private_key(opts),
         {:ok, address} <- do_get_address(private_key) do
      {:ok, [address]}
    end
  end

  defp do_get_address(private_key) do
    with {:ok, pub} <- priv_to_pub(private_key) do
      {:ok, Utils.public_key_to_address(pub)}
    end
  end

  defp validate_private_key(_private_key, nil), do: :ok

  defp validate_private_key(private_key, address) do
    with {:ok, private_key_address} <- do_get_address(private_key) do
      private_key_address_bin = Utils.decode_address!(private_key_address)
      address_bin = Utils.decode_address!(address)

      if address_bin == private_key_address_bin do
        :ok
      else
        {:error, :wrong_key}
      end
    end
  end

  defp priv_to_pub(private_key), do: secp256k1_module().create_public_key(private_key)

  defp private_key(opts) do
    case Keyword.get(opts, :private_key) do
      <<key::binary-32>> -> {:ok, key}
      <<"0x", _::binary-64>> = key -> Ethers.Utils.hex_decode(key)
      <<key::binary-64>> -> Ethers.Utils.hex_decode(key)
      nil -> {:error, :no_private_key}
      _ -> {:error, :invalid_private_key}
    end
  end
end
