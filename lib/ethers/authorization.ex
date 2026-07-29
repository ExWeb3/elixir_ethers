defmodule Ethers.Authorization do
  @moduledoc """
  [EIP-7702](https://eips.ethereum.org/EIPS/eip-7702) authorization.

  An authorization is a signed permit by which an externally-owned account (the *authority*)
  designates contract code to run in its place: once included in a type-4 transaction
  (`Ethers.Transaction.Eip7702`), the authority's account code is set to the delegation
  designator `0xef0100 ++ address`, making every call to the EOA execute the delegate
  contract's code.

  The signed payload is not the tuple itself but its EIP-7702 hash:

      keccak256(0x05 ++ rlp([chain_id, address, nonce]))

  To produce a signature use `Ethers.sign_authorization/2`, which routes through the
  configured `Ethers.Signer`. The signed counterpart is `Ethers.Authorization.Signed`.

  ## Fields

  - `chain_id` - chain where the authorization is valid. **`0` makes it valid on every
    chain** — one signature delegates the authority everywhere (the nonce must still match
    on each chain). Only use `0` deliberately.
  - `address` - the delegate contract whose code the authority's account will run.
    The zero address clears an existing delegation (see `clear/1`).
  - `nonce` - the authority's account nonce **at the time the authorization is applied**
    on chain. When the authority itself sends the type-4 transaction (self-sponsoring),
    the transaction increments the account nonce first, so the authorization nonce must be
    the current nonce **plus one** — see the `:executor` option of
    `Ethers.sign_authorization/2`.

  A mismatched nonce (or a signature with a high `s` value) does not fail the transaction;
  the authorization is silently skipped on chain, so getting these right matters.
  """

  import Ethers.Transaction.Helpers, only: [validate_non_neg_integer: 1, validate_address: 1]

  alias Ethers.Types
  alias Ethers.Utils

  @magic <<0x05>>
  @zero_address "0x0000000000000000000000000000000000000000"

  # EIP-7702: authorization nonce must be < 2^64
  @max_nonce 2 ** 64 - 1

  @enforce_keys [:chain_id, :address, :nonce]
  defstruct [:chain_id, :address, :nonce]

  @typedoc """
  An unsigned EIP-7702 authorization incorporating the following fields:
  - `chain_id` - chain ID the authorization is valid on, or `0` for every chain
  - `address` - the delegate contract address
  - `nonce` - the authority's account nonce at the time the authorization applies
  """
  @type t :: %__MODULE__{
          chain_id: non_neg_integer(),
          address: Types.t_address(),
          nonce: non_neg_integer()
        }

  @doc """
  Creates a new authorization struct with the given parameters.

  Accepts a map or a keyword list with the `:chain_id`, `:address` and `:nonce` keys, all
  required. See the module documentation for the field semantics.

  ## Examples

      iex> Ethers.Authorization.new(chain_id: 1, address: "0x90f8bf6a479f320ead074411a4b0e7944ea8c9c1", nonce: 7)
      {:ok, %Ethers.Authorization{chain_id: 1, address: "0x90F8bf6A479f320ead074411a4B0e7944Ea8c9C1", nonce: 7}}
  """
  @spec new(map() | Keyword.t()) :: {:ok, t()} | {:error, reason :: atom()}
  def new(params) when is_list(params), do: params |> Map.new() |> new()

  def new(params) when is_map(params) do
    with :ok <- validate_required(params[:chain_id], :missing_chain_id),
         :ok <- validate_required(params[:address], :missing_address),
         :ok <- validate_required(params[:nonce], :missing_nonce),
         :ok <- validate_non_neg_integer(params[:chain_id]),
         :ok <- validate_non_neg_integer(params[:nonce]),
         :ok <- validate_nonce_bound(params[:nonce]),
         :ok <- validate_address(params[:address]) do
      {:ok,
       %__MODULE__{
         chain_id: params[:chain_id],
         address: Utils.to_checksum_address(params[:address]),
         nonce: params[:nonce]
       }}
    end
  end

  @doc """
  Same as `new/1` but raises on error.
  """
  @spec new!(map() | Keyword.t()) :: t() | no_return()
  def new!(params) do
    case new(params) do
      {:ok, authorization} -> authorization
      {:error, reason} -> raise ArgumentError, "invalid authorization: #{inspect(reason)}"
    end
  end

  @doc """
  Creates an authorization that clears the authority's delegation.

  Same as `new/1` with the zero address: applying it resets the authority's account code
  to empty instead of writing a delegation designator. This is the only way to remove an
  EIP-7702 delegation. The authority's nonce is still consumed.

  ## Examples

      iex> Ethers.Authorization.clear(chain_id: 1, nonce: 8)
      {:ok, %Ethers.Authorization{chain_id: 1, address: "0x0000000000000000000000000000000000000000", nonce: 8}}
  """
  @spec clear(map() | Keyword.t()) :: {:ok, t()} | {:error, reason :: atom()}
  def clear(params) do
    params
    |> Map.new()
    |> Map.put(:address, @zero_address)
    |> new()
  end

  @doc """
  Same as `clear/1` but raises on error.
  """
  @spec clear!(map() | Keyword.t()) :: t() | no_return()
  def clear!(params) do
    params
    |> Map.new()
    |> Map.put(:address, @zero_address)
    |> new!()
  end

  @doc """
  Calculates the EIP-7702 signing hash of an authorization.

  Returns the 32-byte digest of `keccak256(0x05 ++ rlp([chain_id, address, nonce]))`.
  """
  @spec hash(t()) :: <<_::256>>
  def hash(%__MODULE__{} = authorization) do
    encoded =
      authorization
      |> to_rlp_list()
      |> ExRLP.encode()

    Ethers.keccak_module().hash_256(@magic <> encoded)
  end

  @doc false
  @spec to_rlp_list(t()) :: [binary() | non_neg_integer()]
  def to_rlp_list(%__MODULE__{} = authorization) do
    [
      authorization.chain_id,
      Utils.decode_address!(authorization.address),
      authorization.nonce
    ]
  end

  defp validate_required(nil, error), do: {:error, error}
  defp validate_required(_value, _error), do: :ok

  defp validate_nonce_bound(nonce) when is_integer(nonce) and nonce > @max_nonce,
    do: {:error, :nonce_out_of_range}

  defp validate_nonce_bound(_nonce), do: :ok
end
