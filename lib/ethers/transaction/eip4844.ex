defmodule Ethers.Transaction.Eip4844 do
  @moduledoc """
  Transaction struct and protocol implementation for Ethereum Improvement Proposal (EIP) 4844
  transactions. EIP-4844 introduced "blob-carrying transactions" which contain a large amount
  of data that cannot be accessed by EVM execution, but whose commitment can be accessed.

  See: https://eips.ethereum.org/EIPS/eip-4844
  """

  alias Ethers.Types
  alias Ethers.Utils

  @behaviour Ethers.Transaction

  @type_id 3

  @enforce_keys [
    :chain_id,
    :nonce,
    :max_priority_fee_per_gas,
    :max_fee_per_gas,
    :gas,
    :max_fee_per_blob_gas
  ]
  defstruct [
    :chain_id,
    :nonce,
    :max_priority_fee_per_gas,
    :max_fee_per_gas,
    :gas,
    :to,
    :value,
    :input,
    :max_fee_per_blob_gas,
    access_list: [],
    blob_versioned_hashes: []
  ]

  @typedoc """
  A transaction type following EIP-4844 (Type-3) and incorporating the following fields:
  - `chain_id` - chain ID of network where the transaction is to be executed
  - `nonce` - sequence number for the transaction from this sender
  - `max_priority_fee_per_gas` - maximum fee per gas (in wei) to give to validators as priority fee (introduced in EIP-1559)
  - `max_fee_per_gas` - maximum total fee per gas (in wei) willing to pay (introduced in EIP-1559)
  - `gas` - maximum amount of gas allowed for transaction execution
  - `to` - destination address for transaction, nil for contract creation
  - `value` - amount of ether (in wei) to transfer
  - `input` - data payload of the transaction
  - `access_list` - list of addresses and storage keys to warm up (introduced in EIP-2930)
  - `max_fee_per_blob_gas` - maximum fee per blob gas (in wei) willing to pay (introduced in EIP-4844)
  - `blob_versioned_hashes` - list of versioned hashes of the blobs (introduced in EIP-4844)
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
          access_list: [{binary(), [binary()]}],
          max_fee_per_blob_gas: non_neg_integer(),
          blob_versioned_hashes: [{binary(), [binary()]}]
        }

  @impl Ethers.Transaction
  def new(params) do
    to = params[:to]

    {:ok,
     %__MODULE__{
       chain_id: params.chain_id,
       nonce: params.nonce,
       max_priority_fee_per_gas: params.max_priority_fee_per_gas,
       max_fee_per_gas: params.max_fee_per_gas,
       gas: params.gas,
       to: to && Utils.to_checksum_address(to),
       value: params[:value] || 0,
       input: params[:input] || params[:data] || "",
       access_list: params[:access_list] || [],
       max_fee_per_blob_gas: params.max_fee_per_blob_gas,
       blob_versioned_hashes: params[:blob_versioned_hashes] || []
     }}
  end

  @impl Ethers.Transaction
  def auto_fetchable_fields do
    [:chain_id, :nonce, :max_priority_fee_per_gas, :max_fee_per_gas, :gas, :max_fee_per_blob_gas]
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
        max_fee_per_blob_gas,
        blob_versioned_hashes
        | rest
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
       input: input,
       access_list: access_list,
       max_fee_per_blob_gas: :binary.decode_unsigned(max_fee_per_blob_gas),
       blob_versioned_hashes: blob_versioned_hashes
     }, rest}
  end

  def from_rlp_list(_rlp_list), do: {:error, :transaction_decode_failed}

  defimpl Ethers.Transaction.Protocol do
    def type_id(_transaction), do: @for.type_id()

    def type_envelope(_transaction), do: @for.type_envelope()

    def to_rlp_list(tx, _mode) do
      # Eip4844 requires Eip1559 fields
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
        tx.max_fee_per_blob_gas,
        tx.blob_versioned_hashes || []
      ]
    end
  end
end
