defmodule Ethers.Result do
  @moduledoc """
  Result struct which holds information regarding calls and transactions.
  """

  alias Ether.Types

  defstruct [:transaction_hash, :return_values, :gas_estimate, :to, :data]

  @type t :: %__MODULE__{
          transaction_hash: Types.t_hash() | nil,
          gas_estimate: non_neg_integer() | :not_estimated,
          return_values: [term()] | nil,
          to: Types.t_address() | nil,
          data: binary()
        }

  @spec new(
          map(),
          [term()] | :not_loaded,
          non_neg_integer() | :not_estimated,
          Types.t_hash() | nil
        ) :: t()
  def new(params, return_values, gas_estimate, transaction_hash) do
    {:ok,
     %__MODULE__{
       to: params[:to],
       data: params.data,
       return_values: return_values,
       gas_estimate: gas_estimate || params[:gas],
       transaction_hash: transaction_hash
     }}
  end
end
