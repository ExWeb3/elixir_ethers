defmodule Ethers.Transaction.Metadata do
  @moduledoc """
  Metadata for a transaction like block hash, block number, and transaction index.
  """

  defstruct block_hash: nil,
            block_number: nil,
            transaction_index: nil

  @typedoc """
  Transaction metadata type incorporating the following fields:
  - `block_hash` - hash of the block where the transaction was included
  - `block_number` - block number where the transaction was included
  - `transaction_index` - index of the transaction in the block
  """
  @type t :: %__MODULE__{
          block_hash: binary() | nil,
          block_number: non_neg_integer() | nil,
          transaction_index: non_neg_integer() | nil
        }

  @doc false
  def new!(params) do
    %__MODULE__{
      block_hash: params[:block_hash],
      block_number: params[:block_number],
      transaction_index: params[:transaction_index]
    }
  end
end
