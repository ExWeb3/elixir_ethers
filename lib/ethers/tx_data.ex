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

  defimpl Inspect do
    import Inspect.Algebra

    alias Ethers.Utils

    def inspect(%{selector: selector, data: data}, opts) do
      arguments = ABI.decode(selector, Utils.hex_decode!(data), :input)

      arguments_doc =
        Enum.zip([selector.types, input_names(selector), arguments])
        |> Enum.map(fn {type, name, arg} ->
          Utils.human_arg(arg, type)

          [
            color(ABI.FunctionSelector.encode_type(type), :atom, opts),
            " ",
            if(name, do: color(name, :variable, opts)),
            if(name, do: " "),
            inspect(Utils.human_arg(arg, type))
          ]
          |> Enum.reject(&is_nil/1)
          |> concat()
        end)
        |> Enum.intersperse(concat(color(",", :operator, opts), break(" ")))

      inner =
        concat([
          break(""),
          color("function", :atom, opts),
          " ",
          color(selector.function, :call, opts),
          color("(", :operator, opts),
          nest(concat([break("") | arguments_doc]), 2),
          break(""),
          color(")", :call, opts),
          " ",
          state_mutability(selector, opts)
        ])

      concat([
        color("#Ethers.TxData<", :map, opts),
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

    defp state_mutability(%{state_mutability: state_mutability}, opts)
         when state_mutability in [:non_payable, :payable] do
      color(Atom.to_string(state_mutability), nil, opts)
    end

    defp state_mutability(%{state_mutability: nil}, opts) do
      color("unknown", nil, opts)
    end

    defp state_mutability(%{state_mutability: state_mutability}, opts) do
      color(Atom.to_string(state_mutability), :string, opts)
    end
  end
end
