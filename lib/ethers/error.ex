defmodule Ethers.Error do
  @moduledoc false

  import Inspect.Algebra

  alias Ethers.Utils

  def inspect(%error_module{} = error, opts) do
    arguments = Enum.map(error_module.ordered_argument_keys(), &Map.fetch!(error, &1))

    selector = error_module.function_selector()

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
      concat([
        break(""),
        color("error", :atom, opts),
        " ",
        color(selector.function, :call, opts),
        concat(arguments_doc)
      ])

    concat([
      color("#Ethers.Error<", :map, opts),
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

  defp human_arg(arg, type, opts), do: Inspect.inspect(Utils.human_arg(arg, type), opts)
end
