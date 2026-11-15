defmodule Ethers.Transaction.DecodeHelpers do
  @moduledoc false

  # Field decoders shared by the `from_rlp_list/1` implementations of the transaction types.
  # RLP decoding yields nested lists of binaries, so every field has to be checked for the
  # expected kind (binary or list) and, for fixed size values, the expected byte size. Shape
  # checks reuse the `new/1` validators and report `:transaction_decode_failed`.

  alias Ethers.Transaction.Helpers
  alias Ethers.Types
  alias Ethers.Utils

  @spec decode_to_address(term()) ::
          {:ok, Types.t_address() | nil} | {:error, :invalid_address | :transaction_decode_failed}
  def decode_to_address(""), do: {:ok, nil}
  def decode_to_address(to) when is_binary(to), do: Utils.encode_address(to)
  def decode_to_address(_to), do: {:error, :transaction_decode_failed}

  @spec validate_access_list(term()) :: :ok | {:error, :transaction_decode_failed}
  def validate_access_list(access_list) do
    case Helpers.validate_access_list(access_list) do
      :ok -> :ok
      {:error, :invalid_access_list} -> {:error, :transaction_decode_failed}
    end
  end

  # Only the shape is checked when decoding, so unlike `new/1` an empty list is accepted
  @spec validate_blob_versioned_hashes(term()) :: :ok | {:error, :transaction_decode_failed}
  def validate_blob_versioned_hashes([]), do: :ok

  def validate_blob_versioned_hashes(hashes) do
    case Helpers.validate_blob_versioned_hashes(hashes) do
      :ok -> :ok
      {:error, _reason} -> {:error, :transaction_decode_failed}
    end
  end
end
