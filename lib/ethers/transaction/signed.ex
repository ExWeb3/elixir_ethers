defmodule Ethers.Transaction.Signed do
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

  @legacy_parity_magic_number 27
  @legacy_parity_with_chain_magic_number 35

  def new(params) do
    {:ok,
     %__MODULE__{
       transaction: params.transaction,
       signature_r: params.signature_r,
       signature_s: params.signature_s,
       signature_y_parity_or_v: params.signature_y_parity_or_v
     }}
  end

  def from_rlp_list(rlp_list, transaction) do
    case rlp_list do
      [signature_y_parity_or_v, signature_r, signature_s] ->
        signed_tx =
          maybe_add_chain_id(%__MODULE__{
            transaction: transaction,
            signature_r: signature_r,
            signature_s: signature_s,
            signature_y_parity_or_v: :binary.decode_unsigned(signature_y_parity_or_v)
          })

        {:ok, signed_tx}

      [] ->
        {:error, :no_signature}

      _rlp_list ->
        {:error, :signature_decode_failed}
    end
  end

  defp maybe_add_chain_id(
         %__MODULE__{transaction: %Legacy{chain_id: nil} = legacy_tx} = signed_tx
       ) do
    {chain_id, _recovery_id} = extract_chain_id_and_recovery_id(signed_tx)
    %__MODULE__{signed_tx | transaction: %Legacy{legacy_tx | chain_id: chain_id}}
  end

  defp maybe_add_chain_id(%__MODULE__{} = tx), do: tx

  def from_address(%__MODULE__{} = transaction) do
    hash_bin = Transaction.transaction_hash(transaction.transaction, :bin)

    {_chain_id, recovery_id} = extract_chain_id_and_recovery_id(transaction)

    case Ethers.secp256k1_module().recover(
           hash_bin,
           transaction.signature_r,
           transaction.signature_s,
           recovery_id
         ) do
      {:ok, pubkey} -> Ethers.Utils.public_key_to_address(pubkey)
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Calculates the y-parity or v value for transaction signatures.

  Handles both legacy and EIP-1559 transaction types according to their specifications.

  ## Parameters
    - `tx` - Transaction struct
    - `recovery_id` - Recovery ID from the signature

  ## Returns
    - `integer` - Calculated y-parity or v value
  """
  @spec calculate_y_parity_or_v(t(), binary() | non_neg_integer()) ::
          non_neg_integer()
  def calculate_y_parity_or_v(tx, recovery_id) do
    case tx do
      %Legacy{chain_id: nil} ->
        # EIP-155
        recovery_id + @legacy_parity_magic_number

      %Legacy{chain_id: chain_id} ->
        # EIP-155
        recovery_id + chain_id * 2 + @legacy_parity_with_chain_magic_number

      _tx ->
        # EIP-1559
        recovery_id
    end
  end

  defp extract_chain_id_and_recovery_id(%__MODULE__{transaction: tx, signature_y_parity_or_v: v}) do
    case tx do
      %Legacy{} ->
        cond do
          v >= @legacy_parity_with_chain_magic_number ->
            chain_id = div(v - @legacy_parity_with_chain_magic_number, 2)
            recovery_id = v - chain_id * 2 - @legacy_parity_with_chain_magic_number
            {chain_id, recovery_id}

          true ->
            {nil, v - @legacy_parity_magic_number}
        end

      _tx ->
        {tx.chain_id, v}
    end
  end

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
