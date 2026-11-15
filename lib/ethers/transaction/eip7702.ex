defmodule Ethers.Transaction.Eip7702 do
  @moduledoc """
  Transaction struct and protocol implementation for Ethereum Improvement Proposal (EIP) 7702
  transactions. EIP-7702 introduced "set code transactions" which let externally-owned
  accounts designate contract code to execute in their place via signed authorizations
  (see `Ethers.Authorization`).

  Two constraints set this type apart from EIP-1559 transactions:
  - `to` is required — contract creation is not allowed in type-4 transactions.
  - `authorization_list` must contain at least one `Ethers.Authorization.Signed`, each with
    an authorization accepted by `Ethers.Authorization.new/1` and a `signature_y_parity` of
    `0` or `1`.

  See: https://eips.ethereum.org/EIPS/eip-7702
  """

  import Ethers.Transaction.Helpers

  alias Ethers.Authorization
  alias Ethers.Types
  alias Ethers.Utils

  @behaviour Ethers.Transaction

  @type_id 4

  @required_fields [:chain_id, :nonce, :max_priority_fee_per_gas, :max_fee_per_gas, :gas, :to]

  @enforce_keys [:chain_id, :nonce, :max_priority_fee_per_gas, :max_fee_per_gas, :gas, :to]
  defstruct [
    :chain_id,
    :nonce,
    :max_priority_fee_per_gas,
    :max_fee_per_gas,
    :gas,
    :to,
    :value,
    :input,
    access_list: [],
    authorization_list: []
  ]

  @typedoc """
  A transaction type following EIP-7702 (Type-4) and incorporating the following fields:
  - `chain_id` - chain ID of network where the transaction is to be executed
  - `nonce` - sequence number for the transaction from this sender
  - `max_priority_fee_per_gas` - maximum fee per gas (in wei) to give to validators as priority fee (introduced in EIP-1559)
  - `max_fee_per_gas` - maximum total fee per gas (in wei) willing to pay (introduced in EIP-1559)
  - `gas` - maximum amount of gas allowed for transaction execution
  - `to` - destination address for transaction. Required — type-4 transactions cannot create contracts
  - `value` - amount of ether (in wei) to transfer
  - `input` - data payload of the transaction
  - `access_list` - list of addresses and storage keys to warm up (introduced in EIP-2930)
  - `authorization_list` - list of signed authorizations setting code on their authorities (introduced in EIP-7702)
  """
  @type t :: %__MODULE__{
          chain_id: non_neg_integer(),
          nonce: non_neg_integer(),
          max_priority_fee_per_gas: non_neg_integer(),
          max_fee_per_gas: non_neg_integer(),
          gas: non_neg_integer(),
          to: Types.t_address(),
          value: non_neg_integer(),
          input: binary(),
          access_list: [{binary(), [binary()]}],
          authorization_list: [Authorization.Signed.t()]
        }

  @impl Ethers.Transaction
  def new(params) do
    input = params[:input] || params[:data] || ""
    value = params[:value] || 0
    access_list = params[:access_list] || []

    with :ok <- validate_required(params, @required_fields),
         :ok <- validate_common_fields(params),
         :ok <- validate_non_neg_integer(params.max_priority_fee_per_gas),
         :ok <- validate_non_neg_integer(params.max_fee_per_gas),
         :ok <- validate_non_neg_integer(value),
         :ok <- validate_binary(input),
         :ok <- validate_access_list(access_list),
         :ok <- validate_authorization_list(params[:authorization_list]) do
      {:ok,
       %__MODULE__{
         chain_id: params.chain_id,
         nonce: params.nonce,
         max_priority_fee_per_gas: params.max_priority_fee_per_gas,
         max_fee_per_gas: params.max_fee_per_gas,
         gas: params.gas,
         to: Utils.to_checksum_address(params.to),
         value: value,
         input: input,
         access_list: access_list,
         authorization_list: params.authorization_list
       }}
    end
  end

  @impl Ethers.Transaction
  def auto_fetchable_fields do
    [:chain_id, :nonce, :max_priority_fee_per_gas, :max_fee_per_gas, :gas]
  end

  @impl Ethers.Transaction
  def type_envelope, do: <<type_id()>>

  @impl Ethers.Transaction
  def type_id, do: @type_id

  @impl Ethers.Transaction
  def from_rlp_list([
        chain_id,
        nonce,
        max_priority_fee_per_gas,
        max_fee_per_gas,
        gas,
        to,
        value,
        input,
        access_list,
        authorization_list
        | rest
      ]) do
    with {:ok, to} <- decode_to_address(to),
         {:ok, authorization_list} <- decode_authorization_list(authorization_list) do
      {:ok,
       %__MODULE__{
         chain_id: :binary.decode_unsigned(chain_id),
         nonce: :binary.decode_unsigned(nonce),
         max_priority_fee_per_gas: :binary.decode_unsigned(max_priority_fee_per_gas),
         max_fee_per_gas: :binary.decode_unsigned(max_fee_per_gas),
         gas: :binary.decode_unsigned(gas),
         to: to,
         value: :binary.decode_unsigned(value),
         input: input,
         access_list: access_list,
         authorization_list: authorization_list
       }, rest}
    end
  end

  def from_rlp_list(_rlp_list), do: {:error, :transaction_decode_failed}

  defp decode_to_address(""), do: {:error, :missing_to_address}
  defp decode_to_address(to), do: Utils.encode_address(to)

  defp decode_authorization_list(authorization_list) when is_list(authorization_list) do
    authorization_list
    |> Enum.reduce_while([], fn rlp_list, acc ->
      case Authorization.Signed.from_rlp_list(rlp_list) do
        {:ok, authorization} -> {:cont, [authorization | acc]}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:error, reason} -> {:error, reason}
      authorizations -> {:ok, Enum.reverse(authorizations)}
    end
  end

  defp decode_authorization_list(_authorization_list), do: {:error, :transaction_decode_failed}

  defp validate_authorization_list(list) when list == [] or is_nil(list),
    do: {:error, :empty_authorization_list}

  defp validate_authorization_list(authorization_list) when is_list(authorization_list) do
    Enum.reduce_while(authorization_list, :ok, fn signed_authorization, :ok ->
      case validate_signed_authorization(signed_authorization) do
        :ok -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp validate_authorization_list(_invalid), do: {:error, :invalid_authorization_list}

  defp validate_signed_authorization(
         %Authorization.Signed{authorization: %Authorization{} = authorization} = signed
       ) do
    with :ok <- Authorization.validate(authorization),
         :ok <- validate_y_parity(signed.signature_y_parity),
         :ok <- validate_binary(signed.signature_r) do
      validate_binary(signed.signature_s)
    end
  end

  defp validate_signed_authorization(_invalid), do: {:error, :invalid_authorization_list}

  defimpl Ethers.Transaction.Protocol do
    def type_id(_transaction), do: @for.type_id()

    def type_envelope(_transaction), do: @for.type_envelope()

    def to_rlp_list(tx, _mode) do
      # Eip7702 requires Eip1559 fields
      [
        tx.chain_id,
        tx.nonce,
        tx.max_priority_fee_per_gas,
        tx.max_fee_per_gas,
        tx.gas,
        (tx.to && Utils.decode_address!(tx.to)) || "",
        tx.value,
        tx.input,
        tx.access_list || [],
        Enum.map(tx.authorization_list, &Authorization.Signed.to_rlp_list/1)
      ]
    end
  end
end
