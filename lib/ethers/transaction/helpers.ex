defmodule Ethers.Transaction.Helpers do
  @moduledoc false

  @missing_field_errors %{
    address: :missing_address,
    chain_id: :missing_chain_id,
    gas: :missing_gas,
    gas_price: :missing_gas_price,
    max_fee_per_blob_gas: :missing_max_fee_per_blob_gas,
    max_fee_per_gas: :missing_max_fee_per_gas,
    max_priority_fee_per_gas: :missing_max_priority_fee_per_gas,
    nonce: :missing_nonce,
    to: :missing_to_address
  }

  @doc """
  Returns `{:error, :missing_<field>}` for the first of `fields` that is missing or `nil`.
  """
  @spec validate_required(map(), [atom()]) :: :ok | {:error, atom()}
  def validate_required(params, fields) do
    Enum.find_value(fields, :ok, fn field ->
      if is_nil(Map.get(params, field)), do: {:error, Map.fetch!(@missing_field_errors, field)}
    end)
  end

  @spec validate_non_neg_integer(term()) :: :ok | {:error, :expected_non_neg_integer_value}
  def validate_non_neg_integer(value) when is_integer(value) and value >= 0, do: :ok
  def validate_non_neg_integer(_), do: {:error, :expected_non_neg_integer_value}

  @spec validate_binary(term()) :: :ok | {:error, :expected_binary_value}
  def validate_binary(value) when is_binary(value), do: :ok
  def validate_binary(_), do: {:error, :expected_binary_value}

  @spec validate_address(term()) :: :ok | {:error, :invalid_address_length | :invalid_address}
  def validate_address("0x" <> address) do
    case Ethers.Utils.hex_decode(address) do
      {:ok, <<_address_bin::binary-20>>} -> :ok
      {:ok, _bad_address} -> {:error, :invalid_address_length}
      _ -> {:error, :invalid_address}
    end
  end

  def validate_address(nil), do: :ok
  def validate_address(_invalid), do: {:error, :invalid_address}

  @doc """
  Validates the fields shared by every transaction type.

  Presence is checked separately with `validate_required/2`, so a `nil` `chain_id` only
  reaches this function for pre-EIP-155 legacy transactions and is accepted.
  """
  @spec validate_common_fields(map()) ::
          :ok
          | {:error, :expected_non_neg_integer_value | :invalid_address_length | :invalid_address}
  def validate_common_fields(params) do
    with :ok <- validate_chain_id(Map.get(params, :chain_id)),
         :ok <- validate_non_neg_integer(Map.get(params, :nonce)),
         :ok <- validate_address(Map.get(params, :to)) do
      validate_non_neg_integer(Map.get(params, :gas))
    end
  end

  defp validate_chain_id(nil), do: :ok
  defp validate_chain_id(chain_id), do: validate_non_neg_integer(chain_id)

  @doc """
  Validates EIP-4844 blob versioned hashes: a non-empty list.
  """
  @spec validate_blob_versioned_hashes(term()) ::
          :ok | {:error, :empty_blob_versioned_hashes | :invalid_blob_versioned_hashes}
  def validate_blob_versioned_hashes(hashes) when hashes == [] or is_nil(hashes),
    do: {:error, :empty_blob_versioned_hashes}

  def validate_blob_versioned_hashes(hashes) when is_list(hashes), do: :ok
  def validate_blob_versioned_hashes(_invalid), do: {:error, :invalid_blob_versioned_hashes}

  @spec validate_y_parity(term()) :: :ok | {:error, :invalid_signature_y_parity}
  def validate_y_parity(y_parity) when y_parity in [0, 1], do: :ok
  def validate_y_parity(_y_parity), do: {:error, :invalid_signature_y_parity}
end
