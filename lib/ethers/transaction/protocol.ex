defprotocol Ethers.Transaction.Protocol do
  @moduledoc """
  EVM Transaction Protocol
  """

  @doc """
  Returns the binary value of the transaction type envelope or empty binary if legacy transaction.
  """
  @fallback_to_any true
  @spec type_envelope(t) :: binary()
  def type_envelope(transaction)

  @doc """
  Returns type of transaction as an integer (e.g. Legacy: 0, EIP-1559: 2)
  """
  @fallback_to_any true
  @spec type_id(t) :: non_neg_integer()
  def type_id(transaction)

  @doc """
  Returns a list ready to be RLP encoded for a given transaction.

  ## Parameters
    - `transaction` - Transaction struct
    - `mode` - Specifies what RLP mode is. `:payload` for encoding the transaction payload,
    `:hash` for encoding the transaction hash
  """
  @spec to_rlp_list(t, mode :: :payload | :hash) :: [binary() | [binary()]]
  def to_rlp_list(transaction, mode)
end

defimpl Ethers.Transaction.Protocol, for: Any do
  alias Ethers.Transaction

  def type_id(transaction) do
    type = Map.get(transaction, :type, Transaction.default_transaction_type())
    type.type_id()
  end

  def type_envelope(transaction), do: raise_no_impl(transaction)

  def to_rlp_list(transaction, _mode), do: raise_no_impl(transaction)

  defp raise_no_impl(transaction) do
    raise ArgumentError, "Transaction protocol not implemented for #{inspect(transaction)}"
  end
end
