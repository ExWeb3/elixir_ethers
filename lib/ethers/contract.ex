defmodule Ethers.Contract do
  @moduledoc """
  Dynamically creates modules for ABIs at compile time.

  ## How to use
  You can simply create a new module and call `use Ethers.Contract` in it with the desired parameters.

  ```elixir
  defmodule MyProject.Contract do
    use Ethers.Contract, abi_file: "path/to/abi.json"
  end
  ```

  After this, the functions in your contracts should be accessible just by calling
  ```elixir
  data = MyProject.Contract.example_function(...)

  # Use data to handle eth_call
  Ethers.Contract.call(data, to: "0xADDRESS", from: "0xADDRESS")
  {:ok, [...]}
  ```

  ## Valid `use` options
  - abi: Used to pass in the encoded/decoded json ABI of contract.
  - abi_file: Used to pass in the file path to the json ABI of contract.
  """

  @type action :: :call | :send | :prepare
  @type t_function_output :: %{
          data: binary,
          to: Ethers.Types.t_address(),
          selector: ABI.FunctionSelector.t()
        }
  @type t_event_output :: %{
          topics: [binary],
          address: Ethers.Types.t_address(),
          selector: ABI.FunctionSelector.t()
        }

  defmacro __using__(opts) do
    module = __CALLER__.module
    {opts, _} = Code.eval_quoted(opts, [], __CALLER__)
    {:ok, abi} = read_abi(opts)
    default_address = Keyword.get(opts, :default_address)

    function_selectors =
      abi
      |> ABI.parse_specification(include_events?: true)
      |> Enum.reject(&is_nil(&1.function))

    function_selectors_with_meta =
      Enum.map(function_selectors, fn %{function: function} = selector ->
        %{
          selector: selector,
          has_other_arities: Enum.count(function_selectors, &(&1.function == function)) > 1,
          default_address: default_address
        }
      end)

    functions_ast =
      function_selectors_with_meta
      |> Enum.filter(&(&1.selector.type == :function))
      |> Enum.map(&generate_method(&1, __CALLER__.module))

    events_mod_name = Module.concat(module, EventFilters)

    events =
      function_selectors_with_meta
      |> Enum.filter(&(&1.selector.type == :event))
      |> Enum.map(&generate_event_filter(&1, __CALLER__.module))

    events_module_ast =
      quote do
        defmodule unquote(events_mod_name) do
          @moduledoc "Events for `#{Macro.to_string(unquote(module))}`"

          unquote(events)
        end
      end

    functions_ast ++ [events_module_ast]
  end

  @doc false
  @spec perform_action(action(), map, Keyword.t(), Keyword.t()) ::
          {:ok, [term]}
          | {:ok, Ethers.Types.t_transaction_hash()}
          | {:ok, Ethers.Contract.t_function_output()}
  def perform_action(action, params, overrides \\ [], rpc_opts \\ [])

  def perform_action(:call, params, overrides, rpc_opts),
    do: Ethers.RPC.call(params, overrides, rpc_opts)

  def perform_action(:send, params, overrides, rpc_opts),
    do: Ethers.RPC.send(params, overrides, rpc_opts)

  def perform_action(:prepare, params, overrides, _rpc_opts),
    do: {:ok, Enum.into(overrides, params)}

  def perform_action(action, _params, _overrides, _rpc_opts),
    do: raise("#{__MODULE__} Invalid action: #{inspect(action)}")

  ## Helpers

  @spec generate_method(map(), atom()) :: any()
  defp generate_method(
         %{
           selector: %ABI.FunctionSelector{type: :function} = selector,
           has_other_arities: has_other_arities,
           default_address: default_address
         } = _function_data,
         mod
       ) do
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
      |> Enum.map(&Ethers.Types.to_elixir_type/1)

    func_return_types =
      selector.returns
      |> Enum.map(&Ethers.Types.to_elixir_type/1)

    default_action = get_default_action(selector)

    overrides = get_overrides(has_other_arities)

    defaults =
      %{to: default_address}
      |> Map.reject(fn {_, v} -> is_nil(v) end)
      |> Macro.escape()

    quote location: :keep do
      @doc """
      Executes `#{unquote(human_signature(selector))}` on the contract.

      ## Parameters
      #{unquote(document_types(selector.types, selector.input_names))}
      - overrides: Overrides and options for the call.
        - `:to`: The address of the recipient contract. (**Required**)
        - `:action`: Type of action for this function (`:call`, `:send` or `:prepare`) Default: `#{inspect(unquote(default_action))}`.
        - `:rpc_opts`: Options to pass to the RCP client e.g. `:url`.

      ## Return Types
      #{unquote(document_types(selector.returns))}
      """
      @spec unquote(name)(unquote_splicing(func_input_types), Keyword.t()) ::
              {:ok, unquote(func_return_types)}
              | {:ok, Ethers.Types.t_transaction_hash()}
              | {:ok, Ethers.Contract.t_function_output()}
      def unquote(name)(unquote_splicing(func_args), unquote(overrides)) do
        data =
          unquote(Macro.escape(selector))
          |> ABI.encode([unquote_splicing(func_args)])
          |> Ethers.Utils.hex_encode()

        params =
          %{data: data, selector: unquote(Macro.escape(selector))}
          |> Map.merge(unquote(defaults))

        {rpc_opts, overrides} = Keyword.pop(overrides, :rpc_opts, [])

        {action, overrides} = Keyword.pop(overrides, :action, unquote(default_action))
        Ethers.Contract.perform_action(action, params, overrides, rpc_opts)
      end
    end
  end

  defp generate_event_filter(
         %{
           selector: %ABI.FunctionSelector{type: :event} = selector,
           has_other_arities: has_other_arities,
           default_address: default_address
         } = _function_data,
         mod
       ) do
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

    {indexed_types, non_indexed_types} =
      selector.types
      |> Enum.zip(selector.inputs_indexed)
      |> Enum.reduce({[], []}, fn
        {type, true}, {indexed, non_indexed} ->
          {indexed ++ [type], non_indexed}

        {type, false}, {indexed, non_indexed} ->
          {indexed, non_indexed ++ [type]}
      end)

    func_input_types =
      indexed_types
      |> Enum.map(&Ethers.Types.to_elixir_type/1)

    selector = %{selector | returns: non_indexed_types}

    topic_0 =
      selector
      |> ABI.FunctionSelector.encode()
      |> keccak_module().hash_256()
      |> Ethers.Utils.hex_encode()

    overrides = get_overrides(has_other_arities)

    quote location: :keep do
      @doc """
      Create event filter for `#{unquote(human_signature(selector))}` 

      For each indexed parameter you can either pass in the value you want to 
      filter or `nil` if you don't want to filter.

      ## Parameters
      #{unquote(document_types(indexed_types, selector.input_names))}
      - overrides: Overrides and options for the call. (**Required**)
        - `:address`: The address or list of addresses of the originating contract(s). (**Optional**)

      ## Event Data Types
      #{unquote(document_types(selector.types, selector.input_names))}
      """
      @spec unquote(name)(unquote_splicing(func_input_types), Keyword.t()) ::
              {:ok, Ethers.Contract.t_event_output()}
      def unquote(name)(unquote_splicing(func_args), unquote(overrides)) do
        address = Keyword.get(overrides, :address, unquote(default_address))

        topics = [unquote(topic_0) | unquote(func_args)]

        {:ok, %{topics: topics, address: address, selector: unquote(Macro.escape(selector))}}
      end
    end
  end

  @spec read_abi(Keyword.t()) :: {:ok, [...]} | {:error, atom()}
  defp read_abi(:abi, abi) when is_list(abi), do: {:ok, abi}

  defp read_abi(:abi, %{"abi" => abi}), do: read_abi(:abi, abi)

  defp read_abi(:abi, abi) when is_atom(abi) do
    read_abi(:abi_file, Path.join(:code.priv_dir(:ethers), "abi/#{abi}.json"))
  end

  defp read_abi(:abi, abi) when is_binary(abi) do
    abi = json_module().decode!(abi)
    read_abi(:abi, abi)
  end

  defp read_abi(:abi_file, file) do
    abi = File.read!(file)
    read_abi(:abi, abi)
  end

  defp read_abi(opts) do
    opts
    |> Keyword.take([:abi, :abi_file])
    |> Enum.sort()
    |> List.first()
    |> then(fn {type, data} -> read_abi(type, data) end)
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

  defp get_default_action(%ABI.FunctionSelector{state_mutability: state_mutability}) do
    case state_mutability do
      :view -> :call
      :pure -> :call
      :payable -> :send
      :non_payable -> :send
      _ -> :call
    end
  end

  defp get_overrides(has_other_arities) do
    if has_other_arities do
      # If the same function with different arities exists within the same contract,
      # then we would need to disable defaulting the overrides as this will cause
      # ambiguousness towards the compiler.
      quote do: overrides
    else
      quote do: overrides \\ []
    end
  end

  defp keccak_module, do: Application.get_env(:ethers, :keccak_module, ExKeccak)

  defp json_module, do: Application.get_env(:ethers, :json_module, Jason)
end
