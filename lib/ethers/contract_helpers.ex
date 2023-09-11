defmodule Ethers.ContractHelpers do
  @moduledoc false

  @spec read_abi(Keyword.t()) :: {:ok, [...]} | {:error, atom()}
  def read_abi(opts) do
    case Keyword.take(opts, [:abi, :abi_file]) do
      [{type, data}] ->
        read_abi(type, data)

      _ ->
        {:error, :bad_argument}
    end
  end

  @spec maybe_read_contract_binary(Keyword.t()) :: binary() | nil
  def maybe_read_contract_binary(opts) do
    case Keyword.take(opts, [:abi, :abi_file]) do
      [{type, data}] ->
        maybe_read_contract_binary(type, data)

      _ ->
        raise ArgumentError, "Invalid options"
    end
  end

  def document_types(types, names \\ []) do
    if length(types) <= length(names) do
      Enum.zip(types, names)
    else
      types
    end
    |> Enum.map_join("\n", fn
      {type, ""} ->
        " - `#{inspect(type)}`"

      {type, name} when is_binary(name) or is_atom(name) ->
        " - #{name}: `#{inspect(type)}`"

      type ->
        " - `#{inspect(type)}`"
    end)
  end

  def human_signature(%ABI.FunctionSelector{
        input_names: names,
        types: types,
        function: function
      }) do
    args =
      if is_list(names) and length(types) == length(names) do
        Enum.zip(types, names)
      else
        types
      end
      |> Enum.map_join(", ", fn
        {type, name} when is_binary(name) ->
          String.trim("#{ABI.FunctionSelector.encode_type(type)} #{name}")

        type ->
          "#{ABI.FunctionSelector.encode_type(type)}"
      end)

    "#{function}(#{args})"
  end

  def get_overrides(module, has_other_arities) do
    if has_other_arities do
      # If the same function with different arities exists within the same contract,
      # then we would need to disable defaulting the overrides as this will cause
      # ambiguousness towards the compiler.
      quote context: module do
        overrides
      end
    else
      quote context: module do
        overrides \\ []
      end
    end
  end

  def generate_arguments(mod, types, names) do
    types
    |> Enum.count(& &1)
    |> Macro.generate_arguments(mod)
    |> then(fn args ->
      if length(names) >= length(args) do
        args
        |> Enum.zip(names)
        |> Enum.map(&get_argument_name_ast/1)
      else
        args
      end
    end)
  end

  def maybe_add_to_address(map, module) do
    case module.default_address() do
      nil -> map
      address when is_binary(address) -> Map.put(map, :to, address)
    end
  end

  defp read_abi(:abi, abi) when is_list(abi), do: {:ok, abi}
  defp read_abi(:abi, %{"abi" => abi}), do: read_abi(:abi, abi)

  defp read_abi(:abi, abi) when is_atom(abi) do
    read_abi(:abi_file, Path.join(:code.priv_dir(:ethers), "abi/#{abi}.json"))
  end

  defp read_abi(:abi, abi) when is_binary(abi) do
    abi = Ethers.json_module().decode!(abi)
    read_abi(:abi, abi)
  end

  defp read_abi(:abi_file, file) do
    abi = File.read!(file)
    read_abi(:abi, abi)
  end

  defp get_argument_name_ast({ast, name}) do
    get_argument_name_ast(ast, String.trim(name))
  end

  defp get_argument_name_ast(ast, "_" <> name), do: get_argument_name_ast(ast, name)
  defp get_argument_name_ast(ast, ""), do: ast

  defp get_argument_name_ast({orig, ctx, md}, name) when is_atom(orig) do
    name_atom = String.to_atom(Macro.underscore(name))
    {name_atom, ctx, md}
  end

  defp maybe_read_contract_binary(:abi, abi) when is_list(abi), do: nil
  defp maybe_read_contract_binary(:abi, %{"bin" => bin}) when is_binary(bin), do: bin
  defp maybe_read_contract_binary(:abi, map) when is_map(map), do: nil
  defp maybe_read_contract_binary(:abi, abi) when is_atom(abi), do: nil

  defp maybe_read_contract_binary(:abi, abi) when is_binary(abi) do
    abi = Ethers.json_module().decode!(abi)
    maybe_read_contract_binary(:abi, abi)
  end

  defp maybe_read_contract_binary(:abi_file, file) do
    abi = File.read!(file)
    maybe_read_contract_binary(:abi, abi)
  end
end
