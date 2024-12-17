defmodule Ethers.Transaction.Legacy do
  @moduledoc """
  Legacy transaction struct and implementation of Transaction.Protocol.
  """

  alias Ethers.Types
  alias Ethers.Utils

  @behaviour Ethers.Transaction

  @type_id 0

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

  # Legacy transactions do not have a type envelope
  @impl Ethers.Transaction
  def type_envelope, do: ""

  @impl Ethers.Transaction
  def type_id, do: @type_id

  @impl Ethers.Transaction
  def from_rlp_list([nonce, gas_price, gas, to, value, input | rest]) do
    {:ok,
     %__MODULE__{
       nonce: :binary.decode_unsigned(nonce),
       gas_price: :binary.decode_unsigned(gas_price),
       gas: :binary.decode_unsigned(gas),
       to: (to != "" && Utils.encode_address!(to)) || nil,
       value: :binary.decode_unsigned(value),
       input: Utils.hex_encode(input)
     }, rest}
  end

  def from_rlp_list(_rlp_list), do: {:error, :transaction_decode_failed}

  defimpl Ethers.Transaction.Protocol do
    def type_id(_transaction), do: @for.type_id()

    def type_envelope(_transaction), do: @for.type_envelope()

    def to_rlp_list(tx, mode) do
      [
        tx.nonce,
        tx.gas_price,
        tx.gas,
        (tx.to && Utils.decode_address!(tx.to)) || "",
        tx.value,
        Utils.hex_decode!(tx.input)
      ]
      |> maybe_add_eip_155(tx, mode)
    end

    defp maybe_add_eip_155(base_list, _tx, :payload), do: base_list

    defp maybe_add_eip_155(base_list, %@for{chain_id: nil}, :hash), do: base_list

    defp maybe_add_eip_155(base_list, %@for{chain_id: chain_id}, :hash) do
      base_list ++ [chain_id, 0, 0]
    end
  end
end
