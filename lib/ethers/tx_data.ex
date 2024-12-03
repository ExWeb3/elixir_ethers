defmodule Ethers.TxData do
  @moduledoc """
  Transaction struct to hold information about the ABI selector, encoded data
  and the target `to` address.
  """

  alias Ethers.Utils

  @typedoc """
  Holds transaction data, the function selector and the default `to` address.

  Can be passed in to `Ethers.call/2` or `Ethers.send/2` to execute.
  """
  @type t :: %__MODULE__{
          data: binary() | [binary()],
          selector: ABI.FunctionSelector.t(),
          default_address: nil | Ethers.Types.t_address(),
          base_module: atom() | nil
        }

  @enforce_keys [:data, :selector]
  defstruct [:data, :selector, :default_address, :base_module]

  @doc false
  @spec new(binary(), ABI.FunctionSelector.t(), Ethers.Types.t_address() | nil, atom() | nil) ::
          t()
  def new(data, selector, default_address, base_module) do
    %__MODULE__{
      data: data,
      selector: selector,
      default_address: default_address,
      base_module: base_module
    }
  end

  @doc """
  Converts a TxData struct and optional overrides to a map ready for RPC data.
  """
  @spec to_map(t() | map(), Keyword.t()) :: map()
  def to_map(tx_data, overrides \\ [])

  def to_map(%__MODULE__{} = tx_data, overrides) do
    tx_data
    |> get_tx_map()
    |> to_map(overrides)
  end

  def to_map(tx_map, overrides) when is_map(tx_map) do
    overrides
    |> Enum.into(tx_map)
    |> Map.new(fn
      {k, v} when is_integer(v) -> {k, Ethers.Utils.integer_to_hex(v)}
      kv -> kv
    end)
  end

  @doc """
  ABI decodes a function input/output given a TxData or FunctionSelector
  """
  @spec abi_decode(binary(), ABI.FunctionSelector.t() | t(), type :: :input | :output) ::
          {:ok, any() | [any()]}
  def abi_decode(data, tx_data_or_selector, type \\ :output)

  def abi_decode(data, %{selector: %ABI.FunctionSelector{} = selector}, type),
    do: abi_decode(data, selector, type)

  def abi_decode(data, %ABI.FunctionSelector{} = selector, type) do
    types =
      case type do
        :input -> selector.types
        :output -> selector.returns
      end

    selector
    |> ABI.decode(data, type)
    |> Enum.zip(types)
    |> Enum.map(fn {return, type} -> Utils.human_arg(return, type) end)
    |> case do
      [element] -> {:ok, element}
      elements -> {:ok, elements}
    end
  end

  defp get_tx_map(%{selector: %{type: :function}} = tx_data) do
    %{data: tx_data.data}
    |> maybe_add_to_address(tx_data.default_address)
  end

  defp maybe_add_to_address(tx_map, nil), do: tx_map
  defp maybe_add_to_address(tx_map, address), do: Map.put(tx_map, :to, address)

  defimpl Inspect do
    import Inspect.Algebra

    alias Ethers.Utils

    def inspect(%{selector: selector, data: data, default_address: default_address}, opts) do
      arguments = ABI.decode(selector, Utils.hex_decode!(data), :input)

      arguments_doc =
        Enum.zip([selector.types, input_names(selector), arguments])
        |> Enum.map(fn {type, name, arg} ->
          [
            color(ABI.FunctionSelector.encode_type(type), :atom, opts),
            " ",
            if(name, do: color(name, :variable, opts)),
            if(name, do: " "),
            human_arg(arg, type, opts)
          ]
          |> Enum.reject(&is_nil/1)
          |> concat()
        end)
        |> Enum.intersperse(concat(color(",", :operator, opts), break(" ")))

      returns =
        Enum.zip(selector.returns, selector.return_names)
        |> Enum.map(fn
          {type, ""} ->
            color(ABI.FunctionSelector.encode_type(type), :atom, opts)

          {type, name} ->
            concat([
              color(ABI.FunctionSelector.encode_type(type), :atom, opts),
              " ",
              color(name, :variable, opts)
            ])
        end)
        |> Enum.intersperse(concat(color(",", :operator, opts), break(" ")))

      returns_doc =
        if Enum.count(returns) > 0 do
          [
            " ",
            color("returns ", :atom, opts),
            color("(", :operator, opts),
            nest(concat([break("") | returns]), 2),
            break(""),
            color(")", :operator, opts)
          ]
        else
          []
        end

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

      arguments_doc =
        case arguments_doc do
          [] ->
            [
              color("(", :operator, opts),
              color(")", :operator, opts)
            ]

          _ ->
            [
              color("(", :operator, opts),
              nest(concat([break("") | arguments_doc]), 2),
              break(""),
              color(")", :operator, opts)
            ]
        end

      inner =
        concat(
          [
            break(""),
            color("function", :atom, opts),
            " ",
            color(selector.function, :call, opts),
            concat(arguments_doc),
            " ",
            state_mutability(selector, opts)
          ] ++ returns_doc ++ default_address
        )

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

    defp human_arg(arg, type, opts), do: Inspect.inspect(Utils.human_arg(arg, type), opts)
  end
end
