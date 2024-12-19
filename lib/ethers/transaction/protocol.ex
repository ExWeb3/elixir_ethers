defprotocol Ethers.Transaction.Protocol do
  @moduledoc """
  Protocol for handling Ethereum Virtual Machine (EVM) transactions.
  """

  @doc """
  Returns the binary value of the transaction type envelope.
  For legacy transactions, returns an empty binary.
  """
  @fallback_to_any true
  @spec type_envelope(t) :: binary()
  def type_envelope(transaction)

  @doc """
  Returns type of transaction as an integer.
  """
  @fallback_to_any true
  @spec type_id(t) :: non_neg_integer()
  def type_id(transaction)

  @doc """
  Returns a list ready to be RLP encoded for a given transaction.

  ## Parameters
  - `transaction` - Transaction struct containing the transaction data
  - `mode` - Encoding mode:
    - `:payload` - For encoding the transaction payload
    - `:hash` - For encoding the transaction hash
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

  @dialyzer {:no_return, {:type_envelope, 1}}
  def type_envelope(transaction), do: raise_no_impl(transaction)

  @dialyzer {:no_return, {:to_rlp_list, 2}}
  def to_rlp_list(transaction, _mode), do: raise_no_impl(transaction)

  @dialyzer {:nowarn_function, {:raise_no_impl, 1}}
  defp raise_no_impl(transaction) do
    raise ArgumentError, "Transaction protocol not implemented for #{inspect(transaction)}"
  end
end
