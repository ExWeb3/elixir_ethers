defmodule Ethers.Transaction.DecodeHelpers do
  @moduledoc false

  # Field decoders shared by the `from_rlp_list/1` implementations of the transaction types.
  # RLP decoding yields nested lists of binaries, so every field has to be checked for the
  # expected kind (binary or list) and, for fixed size values, the expected byte size.

  alias Ethers.Types
  alias Ethers.Utils

  @spec decode_to_address(term()) ::
          {:ok, Types.t_address() | nil} | {:error, :invalid_address | :transaction_decode_failed}
  def decode_to_address(""), do: {:ok, nil}
  def decode_to_address(to) when is_binary(to), do: Utils.encode_address(to)
  def decode_to_address(_to), do: {:error, :transaction_decode_failed}

  @spec validate_access_list(term()) :: :ok | {:error, :transaction_decode_failed}
  def validate_access_list(access_list) when is_list(access_list) do
    if Enum.all?(access_list, &access_list_entry?/1) do
      :ok
    else
      {:error, :transaction_decode_failed}
    end
  end

  def validate_access_list(_access_list), do: {:error, :transaction_decode_failed}

  @spec validate_blob_versioned_hashes(term()) :: :ok | {:error, :transaction_decode_failed}
  def validate_blob_versioned_hashes(hashes) when is_list(hashes) do
    if Enum.all?(hashes, &match?(<<_hash::binary-32>>, &1)) do
      :ok
    else
      {:error, :transaction_decode_failed}
    end
  end

  def validate_blob_versioned_hashes(_hashes), do: {:error, :transaction_decode_failed}

  defp access_list_entry?([<<_address::binary-20>>, storage_keys]) when is_list(storage_keys) do
    Enum.all?(storage_keys, &match?(<<_storage_key::binary-32>>, &1))
  end

  defp access_list_entry?(_entry), do: false
end
