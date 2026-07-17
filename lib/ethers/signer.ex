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

  A signer may also implement the optional `c:sign_typed_data/2` callback to support signing
  [EIP-712](https://eips.ethereum.org/EIPS/eip-712) typed structured data (see `Ethers.TypedData`).
  Signers that do not implement it will simply not support typed-data signing.

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

  @doc """
  Signs an [EIP-712](https://eips.ethereum.org/EIPS/eip-712) typed-data payload and returns the
  signature.

  This is an optional callback. Signers that do not implement it do not support typed-data
  signing.

  ## Parameters
   - typed_data: The typed-data payload to sign. (An `Ethers.TypedData` struct)
   - opts: Other options passed to the signer as `signer_opts`.

  Returns `{:ok, signature}` where `signature` is a `0x`-prefixed 65-byte signature hex string.
  """
  @callback sign_typed_data(typed_data :: Ethers.TypedData.t(), opts :: Keyword.t()) ::
              {:ok, binary()} | {:error, reason :: term()}

  @optional_callbacks sign_typed_data: 2
end
