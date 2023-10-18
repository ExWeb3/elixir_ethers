defmodule Ethers.EventFilter do
  @moduledoc """
  Event Filter struct and helper functions to work with the event filters
  """

  @typedoc """
  Holds event filter topics, the event selector and the default address.

  Can be passed in to `Ethers.get_logs/2` filter and fetch the logs.
  """
  @type t :: %__MODULE__{
          topics: [binary()],
          selector: ABI.FunctionSelector.t(),
          address: nil | Ethers.Types.t_address()
        }

  @enforce_keys [:topics, :selector]
  defstruct [:topics, :selector, :address]

  @doc false
  @spec new([binary()], ABI.FunctionSelector.t(), Ethers.Types.t_address() | nil) :: t()
  def new(topics, selector, address) do
    %__MODULE__{
      topics: topics,
      selector: selector,
      address: address
    }
  end

  @doc false
  @spec to_map(t() | map(), Keyword.t()) :: map()
  def to_map(%__MODULE__{} = tx_data, overrides) do
    tx_data
    |> event_filter_map()
    |> to_map(overrides)
  end

  def to_map(event_filter, overrides) do
    Enum.into(overrides, event_filter)
  end

  defp event_filter_map(%{selector: %{type: :event}} = event_filter) do
    %{topics: event_filter.topics}
    |> maybe_add_address(event_filter.address)
  end

  defp maybe_add_address(tx_map, nil), do: tx_map
  defp maybe_add_address(tx_map, address), do: Map.put(tx_map, :address, address)
end
