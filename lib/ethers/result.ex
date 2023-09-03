defmodule Ethers.Result do
  @moduledoc """
  Result struct which holds information regarding calls and transactions.
  """

  alias Ethers.Types

  defstruct [:transaction_hash, :return_values, :gas_estimate, :to, :data]

  @type t(return_values_type) :: %__MODULE__{
          transaction_hash: Types.t_hash() | nil,
          gas_estimate: non_neg_integer() | :not_estimated,
          return_values: return_values_type | nil,
          to: Types.t_address() | nil,
          data: binary()
        }
  @type t :: t([term()])

  @spec new(
          map(),
          [term()] | nil,
          non_neg_integer() | :not_estimated | nil,
          Types.t_hash() | nil
        ) :: t()
  def new(params, return_values, gas_estimate, transaction_hash) do
    %__MODULE__{
      to: params[:to],
      data: params.data,
      return_values: return_values,
      gas_estimate: gas_estimate || params[:gas] || :not_estimated,
      transaction_hash: transaction_hash
    }
  end
end
