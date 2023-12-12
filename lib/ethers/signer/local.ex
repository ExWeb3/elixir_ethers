defmodule Ethers.Signer.Local do
  @moduledoc """
  Local signer works with a private key
  """

  @behaviour Ethers.Signer

  import Ethers, only: [secp256k1_module: 0, keccak_module: 0]

  alias Ethers.Transaction
  alias Ethers.Utils

  unless Code.ensure_loaded?(Ethers.secp256k1_module()) do
    def sign_transaction(_tx, _opts), do: {:error, :secp256k1_module_not_loaded}
    def address(_opts), do: {:error, :secp256k1_module_not_loaded}
  end

  def sign_transaction(%Transaction{} = tx, opts) do
    with {:ok, private_key} <- private_key(opts),
         :ok <- validate_private_key(private_key, tx.from),
         {:ok, {r, s, recovery_id}} <-
           Transaction.encode(tx)
           |> keccak_module().hash_256()
           |> secp256k1_module().sign(private_key) do
      signed =
        %{tx | signature_r: r, signature_s: s, signature_recovery_id: recovery_id}
        |> Transaction.encode()
        |> Utils.hex_encode()

      {:ok, signed}
    end
  end

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

  def public_key(opts) do
    with {:ok, private_key} <- private_key(opts) do
      priv_to_pub(private_key)
    end
  end

  defp validate_private_key(_private_key, nil), do: :ok

  defp validate_private_key(private_key, address) do
    with {:ok, private_key_address} <- do_get_address(private_key) do
      private_key_address = String.downcase(private_key_address)
      address = String.downcase(address)

      if address == private_key_address do
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
      nil -> {:error, :no_private_key}
      _ -> {:error, :invalid_private_key}
    end
  end
end
