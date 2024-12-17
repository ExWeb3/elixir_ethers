defmodule Ethers.Transaction.Eip1559 do
  @moduledoc """
  EIP1559 transaction struct and implementation of Transaction.Protocol.
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
