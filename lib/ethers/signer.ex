defmodule Ethers.Signer do
  @moduledoc """
  Signer behaviour and helper functions.

  A signer module is capable of receiving encoded binary and returning a signature of that binary
  """

  alias Ethers.Types

  @doc """
  Signs a binary and returns the signature

  ## Parameters
   - tx: The transaction object. (An `Ethers.Transaction` struct)
   - opts: Other options passed to the signer as `signer_opts`.
  """
  @callback sign_transaction(
              tx :: Ethers.Transaction.t(),
              opts :: Keyword.t()
            ) ::
              {:ok, encoded_signed_transaction :: binary()} | {:error, reason :: term()}

  @doc """
  Returns the address for signing.

  This method might not be supported by all signers. If a signer does not support this function
  it should return `{:error, :not_supported}`.

  ## Parameters
   - opts: Other options passed to the signer as `signer_opts`
  """
  @callback address(opts :: Keyword.t()) ::
              {:ok, Types.t_address()} | {:error, reason :: :not_supported | term()}
end
