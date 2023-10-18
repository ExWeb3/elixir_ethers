defmodule Ethers.TxData do
  @moduledoc """
  Transaction struct to hold information about the ABI selector, encoded data
  and the target `to` address.
  """

  @typedoc """
  Holds transaction data, the function selector and the default `to` address.

  Can be passed in to `Ethers.call/2` or `Ethers.send/2` to execute.
  """
  @type t :: %__MODULE__{
          data: binary() | [binary()],
          selector: ABI.FunctionSelector.t(),
          to: nil | Ethers.Types.t_address()
        }

  @enforce_keys [:data, :selector]
  defstruct [:data, :selector, :to]

  @doc false
  @spec new(binary(), ABI.FunctionSelector.t(), Ethers.Types.t_address() | nil) :: t()
  def new(data, selector, to) do
    %__MODULE__{
      data: data,
      selector: selector,
      to: to
    }
  end

  @doc false
  @spec to_map(t() | map(), Keyword.t()) :: map()
  def to_map(%__MODULE__{} = tx_data, overrides) do
    tx_data
    |> get_tx_map()
    |> to_map(overrides)
  end

  def to_map(tx_map, overrides) when is_map(tx_map) do
    Enum.into(overrides, tx_map)
  end

  defp get_tx_map(%{selector: %{type: :function}} = tx_data) do
    %{data: tx_data.data}
    |> maybe_add_to_address(tx_data.to)
  end

  defp maybe_add_to_address(tx_map, nil), do: tx_map
  defp maybe_add_to_address(tx_map, address), do: Map.put(tx_map, :to, address)
end
