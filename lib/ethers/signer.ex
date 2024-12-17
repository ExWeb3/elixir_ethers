defmodule Ethers.Signer do
  @moduledoc """
  Signer behaviour.

  A signer module is (at least) capable of signing transactions and listing accounts in the signer.

  ## Builtin Signers
  Ethers ships with some default signers that you can use.

  - `Ethers.Signer.JsonRPC`: Can be used with most wallets, geth, web3signer or any other platform
    which exposes a JsonRPC endpoint and implements `eth_signTransaction` and `eth_accounts`
    functions.
  - `Ethers.Signer.Local`: This signs transactions locally but is highly discouraged to use in
    a production environment as it does not have any security measures built in.

  ## Custom Signers
  Custom signers can also be implemented which must adhere to this behvaviour.

  For signing transactions in custom signers the functions in `Ethers.Transaction` module might
  become handy. Check out the source code of built in signers for in depth info.

  ## Globally Default Signer
  If desired, a signer can be configured to be used for all operations in Ethers using elixir
  config.

  ```elixir
  config :ethers,
    default_signer: Ethers.Signer.JsonRPC,
    default_signer_opts: [url: "..."]
  ```
  """

  alias Ethers.Types

  @doc """
  Signs a binary and returns the signature

  ## Parameters
   - tx: The transaction object. (An `Ethers.Transaction` struct)
   - opts: Other options passed to the signer as `signer_opts`.
  """
  @callback sign_transaction(
              tx :: Ethers.Transaction.t_payload(),
              opts :: Keyword.t()
            ) ::
              {:ok, encoded_signed_transaction :: binary()} | {:error, reason :: term()}

  @doc """
  Returns the available signer account addresses.

  This method might not be supported by all signers. If a signer does not support this function
  it should return `{:error, :not_supported}`.

  ## Parameters
   - opts: Other options passed to the signer as `signer_opts`
  """
  @callback accounts(opts :: Keyword.t()) ::
              {:ok, [Types.t_address()]} | {:error, reason :: :not_supported | term()}
end
