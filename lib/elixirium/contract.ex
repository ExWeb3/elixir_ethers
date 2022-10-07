defmodule Elixirium.Contract do
  @moduledoc """
  Dynamically creates modules for ABIs at compile time.

  ## How to use
  You can simply create a new module and call `use Elixirium.Contract` in it with the desired parameters.

  ```elixir
  defmodule MyProject.Contract do
    use Elixirium.Contract, abi_file: "path/to/abi.json"
  end
  ```

  After this, the functions in your contracts should be accessible just by calling
  ```elixir
  data = MyProject.Contract.example_function(...)

  # Use data to handle eth_call
  Elixirium.Contract.call(data, to: "0xADDRESS", from: "0xADDRESS")
  {:ok, [...]}
  ```

  ## Valid `use` options
  - abi: Used to pass in the encoded/decoded json ABI of contract.
  - abi_file: Used to pass in the file path to the json ABI of contract.
  """

  @type t_function_output :: %{
          data: binary,
          to: Elixirium.Types.t_address(),
          selector: ABI.FunctionSelector.t()
        }
  @type t_event_output :: %{
          topics: [binary],
          address: Elixirium.Types.t_address(),
          selector: ABI.FunctionSelector.t()
        }

  defmacro __using__(opts) do
    module = __CALLER__.module
    {opts, _} = Code.eval_quoted(opts, [], __CALLER__)
    {:ok, abi} = read_abi(opts)

    functions_selectors =
      abi
      |> ABI.parse_specification(include_events?: true)
      |> Enum.reject(&is_nil(&1.function))

    events_mod_name = String.to_atom("#{module}.Events")

    events =
      functions_selectors
      |> Enum.filter(&(&1.type == :event))
      |> Enum.map(&generate_event_filter(&1, __CALLER__.module))

    events_module_ast =
      quote do
        defmodule unquote(events_mod_name) do
          @moduledoc "Events for `#{Macro.to_string(unquote(module))}`"

          unquote(events)
        end
      end

    functions_ast =
      functions_selectors
      |> Enum.filter(&(&1.type == :function))
      |> Enum.map(&generate_method(&1, __CALLER__.module))

    [events_module_ast | functions_ast]
  end

  ## Helpers

  @spec generate_method(ABI.FunctionSelector.t(), atom()) :: any()
  defp generate_method(%ABI.FunctionSelector{type: :function} = selector, mod) do
    name =
      selector.function
      |> Macro.underscore()
      |> String.to_atom()

    func_args =
      selector.types
      |> Enum.count()
      |> Macro.generate_arguments(mod)
      |> then(fn args ->
        if length(selector.input_names) == length(args) do
          args
          |> Enum.zip(selector.input_names)
          |> Enum.map(fn {{_, ctx, md}, name} ->
            if String.starts_with?(name, "_") do
              name
              |> String.slice(1..-1)
            else
              name
            end
            |> Macro.underscore()
            |> String.to_atom()
            |> then(&{&1, ctx, md})
          end)
        else
          args
        end
      end)

    func_input_types =
      selector.types
      |> Enum.map(&Elixirium.Types.to_elixir_type/1)

    func_return_types =
      selector.returns
      |> Enum.map(&Elixirium.Types.to_elixir_type/1)

    quote location: :keep do
      @doc """
      Calls `#{unquote(human_signature(selector))}` 

      ## Parameters
      #{unquote(document_types(selector.types, selector.input_names))}
      - overrides: Overrides and optsions for the call.
        - `:to`: The address of the recepient contract. (**Required**)
        - `:action`: Type of action for this function (`:call`, `:send` or `:prepare`) Default: `:call`.
        - `:rpc_opts`: Options to pass to the RCP client e.g. `:url`.

      ## Return Types
      #{unquote(document_types(selector.returns))}
      """
      @spec unquote(name)(unquote_splicing(func_input_types), Keyword.t()) ::
              {:ok, unquote(func_return_types)}
              | {:ok, Elixirium.Types.t_transaction_hash()}
              | {:ok, Elixirium.Contract.t_function_output()}
      def unquote(name)(unquote_splicing(func_args), overrides) do
        data =
          unquote(Macro.escape(selector))
          |> ABI.encode([unquote_splicing(func_args)])
          |> Elixirium.Utils.hex_encode()

        params = %{data: data, selector: unquote(Macro.escape(selector))}
        {rpc_opts, overrides} = Keyword.pop(overrides, :rpc_opts, [])

        case Keyword.pop(overrides, :action, :call) do
          {:call, overrides} ->
            Elixirium.RPC.call(params, overrides, rpc_opts)

          {:send, overrides} ->
            Elixirium.RPC.send(params, overrides, rpc_opts)

          {:prepare, overrides} ->
            {:ok, Enum.into(overrides, params)}
        end
      end
    end
  end

  defp generate_event_filter(%ABI.FunctionSelector{type: :event} = selector, mod) do
    name =
      selector.function
      |> Macro.underscore()
      |> String.to_atom()

    func_args =
      selector.inputs_indexed
      |> Enum.count(& &1)
      |> Macro.generate_arguments(mod)
      |> then(fn args ->
        if length(selector.input_names) >= length(args) do
          args
          |> Enum.zip(selector.input_names)
          |> Enum.map(fn {{_, ctx, md}, name} ->
            if String.starts_with?(name, "_") do
              name
              |> String.slice(1..-1)
            else
              name
            end
            |> Macro.underscore()
            |> String.to_atom()
            |> then(&{&1, ctx, md})
          end)
        else
          args
        end
      end)

    indexed_types =
      selector.types
      |> Enum.zip(selector.inputs_indexed)
      |> Enum.filter(fn {_, indexed?} -> indexed? end)
      |> Enum.map(fn {type, _} -> type end)

    func_input_types =
      indexed_types
      |> Enum.map(&Elixirium.Types.to_elixir_type/1)

    topic_0 =
      selector
      |> ABI.FunctionSelector.encode()
      |> ExKeccak.hash_256()
      |> Elixirium.Utils.hex_encode()

    quote location: :keep do
      @doc """
      Create event filter for `#{unquote(human_signature(selector))}` 

      For each indexed parameter you can either pass in the value you want to 
      filter or `nil` if you don't want to filter.

      ## Parameters
      #{unquote(document_types(indexed_types, selector.input_names))}
      - overrides: Overrides and optsions for the call.
        - `:address`: The address of the recepient contract. (**Required**)

      ## Event Data Types
      #{unquote(document_types(selector.types, selector.input_names))}
      """
      @spec unquote(name)(unquote_splicing(func_input_types), Keyword.t()) ::
              {:ok, Elixirium.Contract.t_event_output()}
      def unquote(name)(unquote_splicing(func_args), overrides) do
        address = Keyword.fetch!(overrides, :address)

        topics = [unquote(topic_0) | unquote(func_args)]

        %{topics: topics, address: address, selector: unquote(Macro.escape(selector))}
      end
    end
  end

  @spec read_abi(Keyword.t()) :: {:ok, [...]} | {:error, atom()}
  defp read_abi(abi: abi) when is_list(abi), do: {:ok, abi}
  defp read_abi(abi: %{"abi" => abi}), do: {:ok, abi}

  defp read_abi(abi: abi) when is_atom(abi) do
    read_abi(abi_file: Path.join(:code.priv_dir(:elixirium), "abi/#{abi}.json"))
  end

  defp read_abi(abi: abi) when is_binary(abi) do
    with {:ok, abi} <- Jason.decode(abi) do
      read_abi(abi: abi)
    end
  end

  defp read_abi(abi_file: file) do
    with {:ok, abi} <- File.read(file) do
      read_abi(abi: abi)
    end
  end

  defp document_types(types, names \\ []) do
    if length(types) <= length(names) do
      Enum.zip(types, names)
    else
      types
    end
    |> Enum.map(fn
      {type, name} when is_binary(name) ->
        " - #{name}: `#{inspect(type)}`"

      type ->
        " - `#{inspect(type)}`"
    end)
    |> Enum.join("\n")
  end

  defp human_signature(%ABI.FunctionSelector{
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
          "#{ABI.FunctionSelector.encode_type(type)} #{name}"

        type ->
          "#{ABI.FunctionSelector.encode_type(type)}"
      end)
      |> Enum.join(", ")

    "#{function}(#{args})"
  end
end
