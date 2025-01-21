defmodule Ethers.Transaction.Helpers do
  @moduledoc false

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

  @spec validate_common_fields(map()) ::
          :ok | {:error, :expected_non_neg_integer_value | :expected_binary_value}
  def validate_common_fields(params) do
    with :ok <- validate_non_neg_integer(params.chain_id),
         :ok <- validate_non_neg_integer(params.nonce),
         :ok <- validate_address(params[:to]) do
      validate_non_neg_integer(params.gas)
    end
  end
end
