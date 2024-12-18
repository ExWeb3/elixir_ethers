defmodule Ethers.Transaction.Signed do
  @moduledoc """
  A struct that wraps a transaction and its signature values.
  """

  alias Ethers.Transaction
  alias Ethers.Transaction.Legacy

  @enforce_keys [:payload, :signature_r, :signature_s, :signature_y_parity_or_v]
  defstruct [
    :payload,
    :signature_r,
    :signature_s,
    :signature_y_parity_or_v
  ]

  @typedoc """
  A transaction signature envelope that wraps transaction data with its signature components.

  This type supports both Legacy (pre-EIP-155), EIP-155 Legacy, and EIP-1559 transaction formats.
  The signature components consist of:
  - `signature_r`, `signature_s`: The ECDSA signature values as defined in Ethereum's Yellow Paper
  - `signature_y_parity_or_v`: The recovery value that varies by transaction type:
    - For pre-EIP-155 Legacy transactions: v = recovery_id + 27
    - For EIP-155 Legacy transactions: v = recovery_id + chain_id * 2 + 35
    - For EIP-1559 transactions: Just the recovery_id (0 or 1) as specified in EIP-2930

  Related EIPs:
  - [EIP-155](https://eips.ethereum.org/EIPS/eip-155): Simple replay attack protection
  - [EIP-1559](https://eips.ethereum.org/EIPS/eip-1559): Fee market change for ETH 1.0 chain
  - [EIP-2930](https://eips.ethereum.org/EIPS/eip-2930): Optional access lists
  """
  @type t :: %__MODULE__{
          payload: Transaction.t_payload(),
          signature_r: binary(),
          signature_s: binary(),
          signature_y_parity_or_v: non_neg_integer()
        }

  @legacy_parity_magic_number 27
  @legacy_parity_with_chain_magic_number 35

  @doc false
  def new(params) do
    {:ok,
     %__MODULE__{
       payload: params.payload,
       signature_r: params.signature_r,
       signature_s: params.signature_s,
       signature_y_parity_or_v: params.signature_y_parity_or_v
     }}
  end

  @doc false
  def from_rlp_list(rlp_list, payload) do
    case rlp_list do
      [signature_y_parity_or_v, signature_r, signature_s] ->
        signed_tx =
          maybe_add_chain_id(%__MODULE__{
            payload: payload,
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

  defp maybe_add_chain_id(%__MODULE__{payload: %Legacy{chain_id: nil} = legacy_tx} = signed_tx) do
    {chain_id, _recovery_id} = extract_chain_id_and_recovery_id(signed_tx)
    %__MODULE__{signed_tx | payload: %Legacy{legacy_tx | chain_id: chain_id}}
  end

  defp maybe_add_chain_id(%__MODULE__{} = tx), do: tx

  @doc """
  Calculates the from address of a signed transaction using its signature.

  The from address is inferred from the signature of the transaction rather than being explicitly
  specified. This is done by recovering the signer's public key from the signature and then
  deriving the corresponding Ethereum address.

  ## Returns
    - `{:ok, address}` - Successfully recovered from address
    - `{:error, reason}` - Failed to recover address
  """
  @spec from_address(t()) :: {:ok, Ethers.Types.t_address()} | {:error, atom()}
  def from_address(%__MODULE__{} = transaction) do
    hash_bin = Transaction.transaction_hash(transaction.payload, :bin)

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
  @spec calculate_y_parity_or_v(Transaction.t_payload(), binary() | non_neg_integer()) ::
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

  @spec extract_chain_id_and_recovery_id(t()) :: {non_neg_integer() | nil, non_neg_integer()}
  defp extract_chain_id_and_recovery_id(%__MODULE__{payload: tx, signature_y_parity_or_v: v}) do
    case tx do
      %Legacy{} ->
        if v >= @legacy_parity_with_chain_magic_number do
          chain_id = div(v - @legacy_parity_with_chain_magic_number, 2)
          recovery_id = v - chain_id * 2 - @legacy_parity_with_chain_magic_number
          {chain_id, recovery_id}
        else
          {nil, v - @legacy_parity_magic_number}
        end

      _tx ->
        {tx.chain_id, v}
    end
  end

  defimpl Transaction.Protocol do
    def type_id(signed_tx), do: Transaction.Protocol.type_id(signed_tx.pyalod)

    def type_envelope(signed_tx), do: Transaction.Protocol.type_envelope(signed_tx.payload)

    def to_rlp_list(signed_tx, mode) do
      base_list = Transaction.Protocol.to_rlp_list(signed_tx.payload, mode)

      base_list ++ signature_fields(signed_tx)
    end

    defp signature_fields(signed_tx) do
      [signed_tx.signature_y_parity_or_v, signed_tx.signature_r, signed_tx.signature_s]
    end
  end
end
