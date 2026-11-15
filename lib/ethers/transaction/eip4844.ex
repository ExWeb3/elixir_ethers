defmodule Ethers.Transaction.Eip4844 do
  @moduledoc """
  Transaction struct and protocol implementation for Ethereum Improvement Proposal (EIP) 4844
  transactions. EIP-4844 introduced "blob-carrying transactions" which contain a large amount
  of data that cannot be accessed by EVM execution, but whose commitment can be accessed.

  Two constraints set this type apart from EIP-1559 transactions:
  - `to` is required — contract creation is not allowed in type-3 transactions.
  - `blob_versioned_hashes` must contain at least one 32-byte versioned hash.

  > #### Transaction envelope only {: .warning}
  >
  > Only the transaction envelope, which references the blobs by their versioned hashes, is
  > supported. Building or attaching the blob sidecar (the blobs with their KZG commitments and
  > proofs) is not, and without a sidecar a type-3 transaction cannot be broadcast: nodes reject
  > it (e.g. when sent with `Ethers.send_transaction/2`).
  > See [#178](https://github.com/ExWeb3/elixir_ethers/issues/178).

  See: https://eips.ethereum.org/EIPS/eip-4844
  """

  import Ethers.Transaction.Helpers

  alias Ethers.Transaction.DecodeHelpers
  alias Ethers.Types
  alias Ethers.Utils

  @behaviour Ethers.Transaction

  @type_id 3

  @required_fields [
    :chain_id,
    :nonce,
    :max_priority_fee_per_gas,
    :max_fee_per_gas,
    :gas,
    :to,
    :max_fee_per_blob_gas
  ]

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
  - `to` - destination address for transaction. Required — type-3 transactions cannot create contracts
  - `value` - amount of ether (in wei) to transfer
  - `input` - data payload of the transaction
  - `access_list` - list of addresses and storage keys to warm up (introduced in EIP-2930), as
    `[address, storage_keys]` lists of binaries (see `t:Ethers.Types.t_access_list/0`)
  - `max_fee_per_blob_gas` - maximum fee per blob gas (in wei) willing to pay (introduced in EIP-4844)
  - `blob_versioned_hashes` - list of versioned hashes (32-byte binaries) of the blobs (introduced in EIP-4844)
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
          access_list: Types.t_access_list(),
          max_fee_per_blob_gas: non_neg_integer(),
          blob_versioned_hashes: [<<_::256>>]
        }

  @impl Ethers.Transaction
  def new(params) do
    to = params[:to]
    input = params[:input] || params[:data] || ""
    value = params[:value] || 0
    access_list = params[:access_list] || []

    with :ok <- validate_required(params, @required_fields),
         :ok <- validate_common_fields(params),
         :ok <- validate_non_neg_integer(params.max_priority_fee_per_gas),
         :ok <- validate_non_neg_integer(params.max_fee_per_gas),
         :ok <- validate_non_neg_integer(params.max_fee_per_blob_gas),
         :ok <- validate_non_neg_integer(value),
         :ok <- validate_binary(input),
         :ok <- validate_access_list(access_list),
         :ok <- validate_blob_versioned_hashes(params[:blob_versioned_hashes]) do
      {:ok,
       %__MODULE__{
         chain_id: params.chain_id,
         nonce: params.nonce,
         max_priority_fee_per_gas: params.max_priority_fee_per_gas,
         max_fee_per_gas: params.max_fee_per_gas,
         gas: params.gas,
         to: Utils.to_checksum_address(to),
         value: value,
         input: input,
         access_list: access_list,
         max_fee_per_blob_gas: params.max_fee_per_blob_gas,
         blob_versioned_hashes: params.blob_versioned_hashes
       }}
    end
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
      ])
      when is_binary(chain_id) and is_binary(nonce) and is_binary(max_priority_fee_per_gas) and
             is_binary(max_fee_per_gas) and is_binary(gas) and is_binary(value) and
             is_binary(input) and is_binary(max_fee_per_blob_gas) do
    with {:ok, to} <- DecodeHelpers.decode_to_address(to),
         :ok <- DecodeHelpers.validate_access_list(access_list),
         :ok <- DecodeHelpers.validate_blob_versioned_hashes(blob_versioned_hashes) do
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
         max_fee_per_blob_gas: :binary.decode_unsigned(max_fee_per_blob_gas),
         blob_versioned_hashes: blob_versioned_hashes
       }, rest}
    end
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
