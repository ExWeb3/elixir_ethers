defmodule Ethers.Transaction.Eip2930 do
  @moduledoc """
  Transaction struct and protocol implementation for Ethereum Improvement Proposal (EIP) 2930
  transactions. EIP-2930 introduced a new transaction type that includes an access list,
  allowing transactions to pre-specify and pre-pay for account and storage access to mitigate
  gas cost changes from EIP-2929 and prevent contract breakage. The access list format also
  enables future use cases like block-wide witnesses and static state access patterns.

  See: https://eips.ethereum.org/EIPS/eip-2930
  """

  import Ethers.Transaction.Helpers

  alias Ethers.Types
  alias Ethers.Utils

  @behaviour Ethers.Transaction

  @type_id 1

  @enforce_keys [:chain_id, :nonce, :gas_price, :gas]
  defstruct [
    :chain_id,
    :nonce,
    :gas_price,
    :gas,
    :to,
    :value,
    :input,
    access_list: []
  ]

  @typedoc """
  A transaction type following EIP-2930 (Type-1) and incorporating the following fields:
  - `chain_id` - chain ID of network where the transaction is to be executed
  - `nonce` - sequence number for the transaction from this sender
  - `gas_price`: Price willing to pay for each unit of gas (in wei)
  - `gas` - maximum amount of gas allowed for transaction execution
  - `to` - destination address for transaction, nil for contract creation
  - `value` - amount of ether (in wei) to transfer
  - `input` - data payload of the transaction
  - `access_list` - list of addresses and storage keys to warm up (introduced in EIP-2930)
  """
  @type t :: %__MODULE__{
          chain_id: non_neg_integer(),
          nonce: non_neg_integer(),
          gas_price: non_neg_integer(),
          gas: non_neg_integer(),
          to: Types.t_address() | nil,
          value: non_neg_integer(),
          input: binary(),
          access_list: [{binary(), [binary()]}]
        }

  @impl Ethers.Transaction
  def new(params) do
    to = params[:to]
    input = params[:input] || params[:data] || ""
    value = params[:value] || 0

    with :ok <- validate_common_fields(params),
         :ok <- validate_non_neg_integer(params.gas_price),
         :ok <- validate_non_neg_integer(value),
         :ok <- validate_binary(input) do
      {:ok,
       %__MODULE__{
         chain_id: params.chain_id,
         nonce: params.nonce,
         gas_price: params.gas_price,
         gas: params.gas,
         to: to && Utils.to_checksum_address(to),
         value: value,
         input: input,
         access_list: params[:access_list] || []
       }}
    end
  end

  @impl Ethers.Transaction
  def auto_fetchable_fields do
    [:chain_id, :nonce, :gas_price, :gas]
  end

  @impl Ethers.Transaction
  def type_envelope, do: <<type_id()>>

  @impl Ethers.Transaction
  def type_id, do: @type_id

  @impl Ethers.Transaction
  def from_rlp_list([
        chain_id,
        nonce,
        gas_price,
        gas,
        to,
        value,
        input,
        access_list | rest
      ]) do
    {:ok,
     %__MODULE__{
       chain_id: :binary.decode_unsigned(chain_id),
       nonce: :binary.decode_unsigned(nonce),
       gas_price: :binary.decode_unsigned(gas_price),
       gas: :binary.decode_unsigned(gas),
       to: (to != "" && Utils.encode_address!(to)) || nil,
       value: :binary.decode_unsigned(value),
       input: input,
       access_list: access_list
     }, rest}
  end

  def from_rlp_list(_rlp_list), do: {:error, :transaction_decode_failed}

  defimpl Ethers.Transaction.Protocol do
    def type_id(_transaction), do: @for.type_id()

    def type_envelope(_transaction), do: @for.type_envelope()

    def to_rlp_list(tx, _mode) do
      # Eip2930 does not discriminate in RLP encoding between payload and hash
      [
        tx.chain_id,
        tx.nonce,
        tx.gas_price,
        tx.gas,
        (tx.to && Utils.decode_address!(tx.to)) || "",
        tx.value,
        tx.input,
        tx.access_list || []
      ]
    end
  end
end
