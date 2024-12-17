defmodule Ethers.Transaction.Eip1559 do
  @moduledoc """
  Transaction struct and protocol implementation for Ethereum Improvement Proposal (EIP) 1559
  transactions. EIP-1559 introduced a new fee market mechanism with base fee and priority fee.

  See: https://eips.ethereum.org/EIPS/eip-1559
  """

  alias Ethers.Types
  alias Ethers.Utils

  @behaviour Ethers.Transaction

  @type_id 2

  @enforce_keys [:chain_id, :nonce, :max_priority_fee_per_gas, :max_fee_per_gas, :gas]
  defstruct [
    :chain_id,
    :nonce,
    :max_priority_fee_per_gas,
    :max_fee_per_gas,
    :gas,
    :to,
    :value,
    :input,
    access_list: []
  ]

  @typedoc """
  A transaction type following EIP-1559 (Type-2) and incorporating the following fields:
  - `chain_id` - chain ID of network where the transaction is to be executed
  - `nonce` - sequence number for the transaction from this sender
  - `max_priority_fee_per_gas` - maximum fee per gas (in wei) to give to validators as priority fee (introduced in EIP-1559)
  - `max_fee_per_gas` - maximum total fee per gas (in wei) willing to pay (introduced in EIP-1559)
  - `gas` - maximum amount of gas allowed for transaction execution
  - `to` - destination address for transaction, nil for contract creation
  - `value` - amount of ether (in wei) to transfer
  - `input` - data payload of the transaction
  - `access_list` - list of addresses and storage keys to warm up (introduced in EIP-2930)
  """
  @type t :: %__MODULE__{
          chain_id: non_neg_integer(),
          nonce: non_neg_integer(),
          max_priority_fee_per_gas: non_neg_integer(),
          max_fee_per_gas: non_neg_integer(),
          gas: non_neg_integer(),
          to: Types.t_address() | nil,
          value: non_neg_integer(),
          input: binary(),
          access_list: [{binary(), [binary()]}]
        }

  @impl Ethers.Transaction
  def new(params) do
    {:ok,
     %__MODULE__{
       chain_id: params.chain_id,
       nonce: params.nonce,
       max_priority_fee_per_gas: params.max_priority_fee_per_gas,
       max_fee_per_gas: params.max_fee_per_gas,
       gas: params.gas,
       to: params[:to],
       value: params[:value] || 0,
       input: params[:input] || params[:data] || "",
       access_list: params[:access_list] || []
     }}
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
        access_list | rest
      ]) do
    {:ok,
     %__MODULE__{
       chain_id: :binary.decode_unsigned(chain_id),
       nonce: :binary.decode_unsigned(nonce),
       max_priority_fee_per_gas: :binary.decode_unsigned(max_priority_fee_per_gas),
       max_fee_per_gas: :binary.decode_unsigned(max_fee_per_gas),
       gas: :binary.decode_unsigned(gas),
       to: (to != "" && Utils.encode_address!(to)) || nil,
       value: :binary.decode_unsigned(value),
       input: Utils.hex_encode(input),
       access_list: access_list
     }, rest}
  end

  def from_rlp_list(_rlp_list), do: {:error, :transaction_decode_failed}

  defimpl Ethers.Transaction.Protocol do
    def type_id(_transaction), do: @for.type_id()

    def type_envelope(_transaction), do: @for.type_envelope()

    def to_rlp_list(tx, _mode) do
      # Eip1559 does not discriminate in RLP encoding between payload and hash
      [
        tx.chain_id,
        tx.nonce,
        tx.max_priority_fee_per_gas,
        tx.max_fee_per_gas,
        tx.gas,
        (tx.to && Utils.decode_address!(tx.to)) || "",
        tx.value,
        Utils.hex_decode!(tx.input),
        tx.access_list || []
      ]
    end
  end
end
