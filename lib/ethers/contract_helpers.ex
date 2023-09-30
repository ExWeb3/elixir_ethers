defmodule Ethers.ContractHelpers do
  @moduledoc false

  require Logger

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

  def document_help_message(selectors) do
    selectors
    |> Enum.map(& &1.state_mutability)
    |> Enum.uniq()
    |> do_document_help_message()
  end

  defp do_document_help_message([state_mutability]) do
    message =
      case state_mutability do
        sm when sm in [:pure, :view] ->
          """
          This function should only be called for result and never in a transaction on its own. (Use `Ethers.call/2`)
          """

        :non_payable ->
          """
          This function can be used for a transaction or additionally called for results (Use `Ethers.send/2`).
          No amount of Ether can be sent with this function.
          """

        :payable ->
          """
          This function can be used for a transaction or additionally called for results (Use `Ethers.send/2`)."
          It also supports receiving ether from the transaction origin. 
          """
      end

    """
    #{message}

    State mutability: #{document_state_mutabilities([state_mutability])}
    """
  end

  defp do_document_help_message(state_mutabilities) do
    """
    This function has multiple state mutabilities based on the overload that you use.
    You may use the correct action (`Ethers.call/2` or `Ethers.send/2`) to interact with this function
    based on the overload you choose.

    State mutabilities: #{document_state_mutabilities(state_mutabilities)}
    """
  end

  def document_parameters([%{types: []}]), do: ""

  def document_parameters([%{type: :event} | _] = selectors) do
    parameters_docs =
      Enum.map_join(selectors, "\n\n### OR\n", fn selector ->
        {types, names} =
          Enum.zip(selector.types, selector.input_names)
          |> Enum.zip(selector.inputs_indexed)
          |> Enum.filter(&elem(&1, 1))
          |> Enum.map(&elem(&1, 0))
          |> Enum.unzip()

        document_types(types, names)
      end)

    """
    ## Parameter Types (Event indexed topics)

    #{parameters_docs}
    """
  end

  def document_parameters(selectors) do
    parameters_docs =
      Enum.map_join(selectors, "\n\n### OR\n", &document_types(&1.types, &1.input_names))

    """
    ## Function Parameter Types
    #{parameters_docs}
    """
  end

  def document_returns([%{type: :event} | _] = selectors) do
    return_type_docs =
      selectors
      |> Enum.map(fn selector ->
        Enum.zip([selector.types, selector.input_names, selector.inputs_indexed])
        |> Enum.reject(&elem(&1, 2))
        |> Enum.map(fn {type, name, false} -> {type, name} end)
        |> Enum.unzip()
      end)
      |> Enum.uniq()
      |> Enum.map_join("\n\n### OR\n", fn
        {[], _input_names} ->
          "This event does not contain any values!"

        {types, input_names} ->
          document_types(types, input_names)
      end)

    """
    ## Event `data` Types (when called with `Ethers.get_logs/2`)

    These are non-indexed topics (often referred to as data) of the event log.

    #{return_type_docs}
    """
  end

  def document_returns(selectors) when is_list(selectors) do
    return_type_docs =
      selectors
      |> Enum.map(& &1.returns)
      |> Enum.uniq()
      |> Enum.map_join("\n\n### OR\n", fn returns ->
        if Enum.count(returns) > 0 do
          document_types(returns)
        else
          "This function does not return any values!"
        end
      end)

    """
    ## Return Types (when called with `Ethers.call/2`)
    #{return_type_docs}
    """
  end

  defp document_state_mutabilities(state_mutabilities) do
    Enum.join(state_mutabilities, " OR ")
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

  def human_signature(selectors) when is_list(selectors) do
    Enum.map_join(selectors, " OR ", &human_signature/1)
  end

  def generate_arguments(mod, arity, names) when is_integer(arity) do
    arity
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

  def generate_typespecs(selectors) do
    Enum.map(selectors, & &1.types)
    |> do_generate_typescpecs()
  end

  def generate_event_typespecs(selectors, arity) do
    Enum.map(selectors, &Enum.take(&1.types, arity))
    |> do_generate_typescpecs()
  end

  defp do_generate_typescpecs(types) do
    Enum.zip_with(types, & &1)
    |> Enum.map(fn type_group ->
      type_group
      |> Enum.map(&Ethers.Types.to_elixir_type/1)
      |> Enum.uniq()
      |> Enum.reduce(fn type, acc ->
        quote do
          unquote(type) | unquote(acc)
        end
      end)
    end)
  end

  def find_selector!(selectors, args) do
    filtered_selectors = Enum.filter(selectors, &selector_match?(&1, args))

    case filtered_selectors do
      [] ->
        signatures =
          Enum.map_join(selectors, "\n", &human_signature/1)

        raise ArgumentError, """
        No function selector matches current arguments!

        ## Arguments
        #{inspect(args)}

        ## Available signatures
        #{signatures}
        """

      [selector] ->
        {selector, strip_typed_args(args)}

      selectors ->
        signatures =
          Enum.map_join(selectors, "\n", &human_signature/1)

        raise ArgumentError, """
        Ambiguous parameters

        ## Arguments
        #{inspect(args)}

        ## Possible signatures
        #{signatures}
        """
    end
  end

  defp strip_typed_args(args) do
    Enum.map(args, fn
      {:typed, _type, arg} -> arg
      arg -> arg
    end)
  end

  def selector_match?(%{type: :event} = selector, args) do
    event_indexed_types(selector)
    |> do_selector_match?(args, true)
  end

  def selector_match?(selector, args) do
    do_selector_match?(selector.types, args, false)
  end

  defp do_selector_match?(types, args, allow_nil) do
    if Enum.count(types) == Enum.count(args) do
      Enum.zip(types, args)
      |> Enum.all?(fn
        {type, {:typed, assigned_type, _arg}} -> assigned_type == type
        {_type, nil} -> allow_nil == true
        {type, arg} -> Ethers.Types.matches_type?(arg, type)
      end)
    else
      false
    end
  end

  def aggregate_input_names([%{type: :event} | _] = selectors) do
    Enum.map(selectors, fn selector ->
      Enum.zip(selector.input_names, selector.inputs_indexed)
      |> Enum.filter(&elem(&1, 1))
      |> Enum.map(&elem(&1, 0))
    end)
    |> Enum.zip_with(&(Enum.uniq(&1) |> Enum.join("_or_")))
  end

  def aggregate_input_names(selectors) do
    Enum.map(selectors, & &1.input_names)
    |> Enum.zip_with(&(Enum.uniq(&1) |> Enum.join("_or_")))
  end

  def maybe_add_to_address(map, module, field_name \\ :to) do
    case module.__default_address__() do
      nil -> map
      address when is_binary(address) -> Map.put(map, field_name, address)
    end
  end

  def encode_event_topics(selector, args) do
    [event_topic_0(selector) | encode_event_sub_topics(selector, args)]
  end

  defp event_topic_0(selector) do
    selector
    |> ABI.FunctionSelector.encode()
    |> Ethers.keccak_module().hash_256()
    |> Ethers.Utils.hex_encode()
  end

  defp encode_event_sub_topics(selector, raw_args) do
    event_indexed_types(selector)
    |> Enum.zip(raw_args)
    |> Enum.map(fn
      {_, nil} ->
        nil

      {type, value} when type in unquote(Ethers.Types.dynamically_sized_types()) ->
        value
        |> Ethers.Utils.prepare_arg(type)
        |> Ethers.keccak_module().hash_256()
        |> Ethers.Utils.hex_encode()

      {type, value} ->
        value
        |> Ethers.Utils.prepare_arg(type)
        |> List.wrap()
        |> ABI.TypeEncoder.encode([type])
        |> Ethers.Utils.hex_encode()
    end)
  end

  def event_indexed_types(selector) do
    Enum.zip(selector.types, selector.inputs_indexed)
    |> Enum.filter(&elem(&1, 1))
    |> Enum.map(&elem(&1, 0))
  end

  def event_non_indexed_types(selector) do
    Enum.zip(selector.types, selector.inputs_indexed)
    |> Enum.reject(&elem(&1, 1))
    |> Enum.map(&elem(&1, 0))
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
