defmodule Ethers.ContractHelpers do
  @moduledoc false

  def read_abi(:abi, abi) when is_list(abi), do: {:ok, abi}
  def read_abi(:abi, %{"abi" => abi}), do: read_abi(:abi, abi)

  def read_abi(:abi, abi) when is_atom(abi) do
    read_abi(:abi_file, Path.join(:code.priv_dir(:ethers), "abi/#{abi}.json"))
  end

  def read_abi(:abi, abi) when is_binary(abi) do
    abi = Ethers.json_module().decode!(abi)
    read_abi(:abi, abi)
  end

  def read_abi(:abi_file, file) do
    abi = File.read!(file)
    read_abi(:abi, abi)
  end

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
        {:error, :bad_argument}
    end
  end

  def document_types(types, names \\ []) do
    if length(types) <= length(names) do
      Enum.zip(types, names)
    else
      types
    end
    |> Enum.map(fn
      {type, ""} ->
        " - `#{inspect(type)}`"

      {type, name} when is_binary(name) or is_atom(name) ->
        " - #{name}: `#{inspect(type)}`"

      type ->
        " - `#{inspect(type)}`"
    end)
    |> Enum.join("\n")
  end

  def human_signature(%ABI.FunctionSelector{
        input_names: names,
        types: types,
        function: function
      }) do
    args =
      if length(types) == length(names) do
        Enum.zip(types, names)
      else
        types
      end
      |> Enum.map(fn
        {type, name} when is_binary(name) ->
          String.trim("#{ABI.FunctionSelector.encode_type(type)} #{name}")

        type ->
          "#{ABI.FunctionSelector.encode_type(type)}"
      end)
      |> Enum.join(", ")

    "#{function}(#{args})"
  end

  def get_default_action(%ABI.FunctionSelector{state_mutability: state_mutability}) do
    case state_mutability do
      :view -> :call
      :pure -> :call
      :payable -> :send
      :non_payable -> :send
      _ -> :call
    end
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

  def get_argument_name_ast({ast, name}) do
    do_get_argument_name_ast(ast, String.trim(name))
  end

  def do_get_argument_name_ast(ast, "_" <> name), do: do_get_argument_name_ast(ast, name)
  def do_get_argument_name_ast(ast, ""), do: ast

  def do_get_argument_name_ast({orig, ctx, md}, name) when is_atom(orig) do
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
