defmodule Ethers.Transaction.SignedTransaction do
  @moduledoc """
  A struct that wraps a transaction and its signature values.
  """

  alias Ethers.Transaction
  alias Ethers.Transaction.Legacy

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

  defimpl Transaction.Protocol do
    def type(signed_tx), do: Transaction.Protocol.type(signed_tx.transaction)

    def type_id(signed_tx), do: Transaction.Protocol.type_id(signed_tx.transaction)

    def type_envelope(signed_tx), do: Transaction.Protocol.type_envelope(signed_tx.transaction)

    def to_rlp_list(signed_tx) do
      base_list = Transaction.Protocol.to_rlp_list(signed_tx.transaction)

      base_list ++ signature_fields(signed_tx)
    end

    defp signature_fields(%@for{
           transaction: %Legacy{chain_id: chain_id}
         })
         when not is_nil(chain_id) do
      [chain_id, 0, 0]
    end

    defp signature_fields(signed_tx) do
      [signed_tx.signature_y_parity_or_v, signed_tx.signature_r, signed_tx.signature_s]
    end
  end
end
