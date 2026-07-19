defmodule Ethers.CombinedEventFilter do
  @moduledoc """
  A filter matching any of multiple events (OR semantics) in a single `eth_getLogs` request.

  Combined event filters are created with `Ethers.EventFilter.combine/1` or with the
  generated `EventFilters.all/0` function of a contract module and can be used anywhere
  a regular event filter is accepted (e.g. `Ethers.get_logs/2` and `Ethers.batch/2`).

  The topics of the combined filters are sent to the RPC endpoint as an OR-ed list of
  `topic_0` values so filtering happens server side. Fetched logs are decoded using the
  event selector matching their first topic.

  ## Limitations

  - Only filters with wildcard indexed arguments (all `nil`) can be combined. Combining
    filters with indexed-argument values would create cross-product OR semantics on the
    topics and match unintended logs.
  - All combined filters must belong to the same address. Filters with conflicting
    default addresses cannot be combined since `eth_getLogs` accepts a single address.

  ## Examples

  ```elixir
  filter =
    Ethers.EventFilter.combine([
      Ethers.Contracts.ERC20.EventFilters.transfer(nil, nil),
      Ethers.Contracts.ERC20.EventFilters.approval(nil, nil)
    ])

  Ethers.get_logs(filter, address: "0x...")
  {:ok, [%Ethers.Event{...}, ...]}
  ```
  """

  alias Ethers.ContractHelpers
  alias Ethers.Event
  alias Ethers.EventFilter

  @typedoc """
  Holds the combined topics (a single OR-ed list of `topic_0` values), the event
  selectors indexed by their `topic_0` and the default address.
  """
  @type t :: %__MODULE__{
          topics: [[binary()]],
          selectors: %{binary() => ABI.FunctionSelector.t()},
          default_address: nil | Ethers.Types.t_address()
        }

  @enforce_keys [:topics, :selectors]
  defstruct [:topics, :selectors, :default_address]

  @doc false
  @spec new([EventFilter.t()]) :: t()
  def new([_ | _] = event_filters) do
    Enum.each(event_filters, &validate_filter!/1)

    {topic_0s, selectors} =
      Enum.reduce(event_filters, {[], %{}}, fn %EventFilter{topics: [topic_0 | _]} = filter,
                                               {topic_0s, selectors} ->
        topic_0 = String.downcase(topic_0)

        if Map.has_key?(selectors, topic_0) do
          {topic_0s, selectors}
        else
          {[topic_0 | topic_0s], Map.put(selectors, topic_0, filter.selector)}
        end
      end)

    %__MODULE__{
      topics: [Enum.reverse(topic_0s)],
      selectors: selectors,
      default_address: combined_default_address!(event_filters)
    }
  end

  def new(event_filters) when is_list(event_filters) do
    raise ArgumentError, "cannot combine an empty list of event filters"
  end

  @doc false
  @spec from_events_module(module()) :: t()
  def from_events_module(events_module) do
    events_module.__events__()
    |> Enum.map(fn selector ->
      wildcard_args = Enum.map(ContractHelpers.event_indexed_types(selector), fn _ -> nil end)

      selector
      |> ContractHelpers.encode_event_topics(wildcard_args)
      |> EventFilter.new(selector, events_module.__default_address__())
    end)
    |> new()
  end

  @doc false
  @spec to_map(t(), Keyword.t()) :: map()
  def to_map(%__MODULE__{} = combined_filter, overrides) do
    %{topics: combined_filter.topics}
    |> maybe_add_address(combined_filter.default_address)
    |> then(&Enum.into(overrides, &1))
  end

  @doc """
  Decodes fetched logs using the matching event selectors of the combined filter.

  Logs not matching any of the combined events are discarded. (Cannot happen with logs
  fetched using the combined filter itself, since the RPC endpoint only returns logs
  matching the requested topics)
  """
  @spec decode_logs([map()], t()) :: [Event.t()]
  def decode_logs(logs, %__MODULE__{selectors: selectors}) when is_list(logs) do
    Enum.flat_map(logs, fn log ->
      [topic_0 | _] = Map.fetch!(log, "topics")

      case Map.fetch(selectors, String.downcase(topic_0)) do
        {:ok, selector} -> [Event.decode(log, selector)]
        :error -> []
      end
    end)
  end

  defp validate_filter!(%EventFilter{topics: [_topic_0 | sub_topics]} = filter) do
    if Enum.all?(sub_topics, &is_nil/1) do
      :ok
    else
      raise ArgumentError,
            "cannot combine event filter with indexed-argument values: #{inspect(filter)}" <>
              " (use nil as a wildcard for all indexed arguments)"
    end
  end

  defp validate_filter!(other) do
    raise ArgumentError, "expected an Ethers.EventFilter struct, got: #{inspect(other)}"
  end

  defp combined_default_address!(event_filters) do
    event_filters
    |> Enum.map(& &1.default_address)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq_by(&String.downcase/1)
    |> case do
      [] ->
        nil

      [address] ->
        address

      addresses ->
        raise ArgumentError,
              "cannot combine event filters with conflicting default addresses: " <>
                "#{inspect(addresses)} (eth_getLogs accepts a single address," <>
                " combine filters of the same contract)"
    end
  end

  defp maybe_add_address(map, nil), do: map
  defp maybe_add_address(map, address), do: Map.put(map, :address, address)

  defimpl Inspect do
    import Inspect.Algebra

    def inspect(
          %{topics: [topic_0s], selectors: selectors, default_address: default_address},
          opts
        ) do
      default_address =
        case default_address do
          nil ->
            []

          _ ->
            [
              line(),
              color("default_address: ", :default, opts),
              color(inspect(default_address), :string, opts)
            ]
        end

      events =
        topic_0s
        |> Enum.map(&Map.fetch!(selectors, &1))
        |> Enum.map(fn selector ->
          concat([
            line(),
            color("event", :atom, opts),
            " ",
            color(ABI.FunctionSelector.encode(selector), :call, opts)
          ])
        end)

      inner = concat(events ++ default_address)

      concat([
        color("#Ethers.CombinedEventFilter<", :map, opts),
        nest(inner, 2),
        break(""),
        color(">", :map, opts)
      ])
    end
  end
end
