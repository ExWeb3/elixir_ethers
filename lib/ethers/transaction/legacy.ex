defmodule Ethers.Transaction.Legacy do
  @moduledoc """
  Legacy transaction struct and implementation of Transaction.Protocol.
  """

  alias Ethers.Types
  alias Ethers.Utils

  @behaviour Ethers.Transaction

  @enforce_keys [:nonce, :gas_price, :gas]
  defstruct [
    :nonce,
    :gas_price,
    :gas,
    :to,
    :value,
    :input,
    :chain_id
  ]

  @type t :: %__MODULE__{
          nonce: non_neg_integer(),
          gas_price: non_neg_integer(),
          gas: non_neg_integer(),
          to: Types.t_address() | nil,
          value: non_neg_integer(),
          input: binary(),
          chain_id: non_neg_integer() | nil
        }

  @impl Ethers.Transaction
  def new(params) do
    {:ok,
     %__MODULE__{
       nonce: params.nonce,
       gas_price: params.gas_price,
       gas: params.gas,
       to: params[:to],
       value: params[:value] || 0,
       input: params[:input] || params[:data] || "",
       chain_id: params[:chain_id]
     }}
  end

  @impl Ethers.Transaction
  def auto_fetchable_fields do
    [:chain_id, :nonce, :gas_price, :gas]
  end

  @impl Ethers.Transaction
  def type_id, do: 0

  defimpl Ethers.Transaction.Protocol do
    def type(_transaction), do: :legacy

    def type_id(_transaction), do: @for.type_id()

    def type_envelope(_transaction), do: ""

    def to_rlp_list(tx) do
      [
        tx.nonce,
        tx.gas_price,
        tx.gas,
        (tx.to && Utils.decode_address!(tx.to)) || "",
        tx.value,
        Utils.hex_decode!(tx.input)
      ]
    end
  end
end
