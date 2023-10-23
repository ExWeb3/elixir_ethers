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
          default_address: nil | Ethers.Types.t_address()
        }

  @enforce_keys [:topics, :selector]
  defstruct [:topics, :selector, :default_address]

  @doc false
  @spec new([binary()], ABI.FunctionSelector.t(), Ethers.Types.t_address() | nil) :: t()
  def new(topics, selector, default_address) do
    %__MODULE__{
      topics: topics,
      selector: selector,
      default_address: default_address
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
    |> maybe_add_address(event_filter.default_address)
  end

  defp maybe_add_address(tx_map, nil), do: tx_map
  defp maybe_add_address(tx_map, address), do: Map.put(tx_map, :address, address)

  defimpl Inspect do
    import Inspect.Algebra

    alias Ethers.Utils

    def inspect(
          %{selector: selector, topics: [_t0 | topics], default_address: default_address},
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

      inner =
        concat(
          [
            break(""),
            color("event", :atom, opts),
            " ",
            color(selector.function, :call, opts),
            color("(", :operator, opts),
            nest(concat([break("") | argument_doc(selector, topics, opts)]), 2),
            break(""),
            color(")", :call, opts)
          ] ++ default_address
        )

      concat([
        color("#Ethers.EventFilter<", :map, opts),
        nest(inner, 2),
        break(""),
        color(">", :map, opts)
      ])
    end

    defp input_names(selector) do
      if Enum.count(selector.types) == Enum.count(selector.input_names) do
        selector.input_names
      else
        1..Enum.count(selector.types)
        |> Enum.map(fn _ -> nil end)
      end
    end

    defp argument_doc(selector, topics, opts),
      do:
        argument_doc(
          selector.types,
          input_names(selector),
          selector.inputs_indexed,
          topics,
          [],
          opts
        )

    defp argument_doc(types, input_names, inputs_indexed, topics, acc, opts)

    defp argument_doc([], _, _, _, acc, opts) do
      Enum.reverse(acc)
      |> Enum.intersperse(concat(color(",", :operator, opts), break(" ")))
    end

    defp argument_doc(
           [type | types],
           [name | input_names],
           [true | inputs_indexed],
           [topic | topics],
           acc,
           opts
         ) do
      doc =
        [
          color(ABI.FunctionSelector.encode_type(type), :atom, opts),
          " ",
          color("indexed", nil, opts),
          if(name, do: " "),
          if(name, do: color(name, :variable, opts)),
          " ",
          if(is_nil(topic), do: color("any", :string, opts), else: human_topic(type, topic))
        ]
        |> Enum.reject(&is_nil/1)
        |> concat()

      argument_doc(types, input_names, inputs_indexed, topics, [doc | acc], opts)
    end

    defp argument_doc(
           [type | types],
           [name | input_names],
           [false | inputs_indexed],
           topics,
           acc,
           opts
         ) do
      doc =
        [
          color(ABI.FunctionSelector.encode_type(type), :atom, opts),
          if(name, do: " "),
          if(name, do: color(name, :variable, opts))
        ]
        |> Enum.reject(&is_nil/1)
        |> concat()

      argument_doc(types, input_names, inputs_indexed, topics, [doc | acc], opts)
    end

    defp human_topic(type, topic) do
      hashed? =
        case type do
          type when type in [:string, :bytes] -> true
          {:array, _} -> true
          {:array, _, _} -> true
          {:tuple, _} -> true
          _ -> false
        end

      if hashed? do
        "(hashed) #{inspect(topic)}"
      else
        [value] =
          Utils.hex_decode!(topic)
          |> ABI.TypeDecoder.decode([type])

        inspect(Utils.human_arg(value, type))
      end
    end
  end
end
