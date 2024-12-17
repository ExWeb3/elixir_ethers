defmodule Ethers.Transaction.SignedTransaction do
  @moduledoc """
  A struct that wraps a transaction and its signature values.
  """

  alias Ethers.Transaction

  @behaviour Ethers.Transaction

  @enforce_keys [:transaction, :signature_r, :signature_s, :signature_y_parity_or_v]
  defstruct [
    :transaction,
    :signature_r,
    :signature_s,
    :signature_y_parity_or_v
  ]

  @type t :: %__MODULE__{
          transaction: Transaction.Legacy.t() | Transaction.Eip1559.t(),
          signature_r: binary(),
          signature_s: binary(),
          signature_y_parity_or_v: binary() | non_neg_integer()
        }

  @impl Ethers.Transaction
  def new(params) do
    {:ok,
     %__MODULE__{
       transaction: params.transaction,
       signature_r: params.signature_r,
       signature_s: params.signature_s,
       signature_y_parity_or_v: params.signature_y_parity_or_v
     }}
  end

  @impl Ethers.Transaction
  def auto_fetchable_fields, do: []

  @impl Ethers.Transaction
  def type_envelope, do: raise("Not supported")

  @impl Ethers.Transaction
  def type_id, do: raise("Not supported")

  defimpl Transaction.Protocol do
    def type_id(signed_tx), do: Transaction.Protocol.type_id(signed_tx.transaction)

    def type_envelope(signed_tx), do: Transaction.Protocol.type_envelope(signed_tx.transaction)

    def to_rlp_list(signed_tx, mode) do
      base_list = Transaction.Protocol.to_rlp_list(signed_tx.transaction, mode)

      base_list ++ signature_fields(signed_tx)
    end

    defp signature_fields(signed_tx) do
      [signed_tx.signature_y_parity_or_v, signed_tx.signature_r, signed_tx.signature_s]
    end
  end
end
