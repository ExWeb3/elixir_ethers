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
  - default_address: Default contract deployed address. Can be overridden with `:to` option in every function.
  """

  require Ethers.ContractHelpers
  import Ethers.ContractHelpers

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

  @default_constructor %{
    selector: %ABI.FunctionSelector{
      function: nil,
      method_id: nil,
      type: :constructor,
      inputs_indexed: nil,
      state_mutability: nil,
      input_names: [],
      types: [],
      returns: []
    }
  }

  defmacro __using__(opts) do
    compiler_module = __MODULE__

    quote do
      @before_compile unquote(compiler_module)
      Module.put_attribute(__MODULE__, :_ethers_using_opts, unquote(opts))
    end
  end

  defmacro __before_compile__(env) do
    module = env.module

    {opts, _} =
      module
      |> Module.get_attribute(:_ethers_using_opts)
      |> Code.eval_quoted([], env)

    {:ok, abi} = read_abi(opts)
    contract_binary = maybe_read_contract_binary(opts)
    default_address = Keyword.get(opts, :default_address)

    function_selectors = ABI.parse_specification(abi, include_events?: true)

    function_selectors_with_meta =
      Enum.map(function_selectors, fn %{function: function} = selector ->
        %{
          selector: selector,
          has_other_arities: Enum.count(function_selectors, &(&1.function == function)) > 1,
          default_address: default_address
        }
      end)

    constructor_ast =
      function_selectors_with_meta
      |> Enum.find(&(&1.selector.type == :constructor))
      |> then(&(&1 || @default_constructor))
      |> generate_method(module)

    functions_ast =
      function_selectors_with_meta
      |> Enum.filter(&(&1.selector.type == :function and not is_nil(&1.selector.function)))
      |> Enum.map(&generate_method(&1, module))

    events_mod_name = Module.concat(module, EventFilters)

    events =
      function_selectors_with_meta
      |> Enum.filter(&(&1.selector.type == :event))
      |> Enum.map(&generate_event_filter(&1, module))

    events_module_ast =
      quote context: module do
        defmodule unquote(events_mod_name) do
          @moduledoc "Events for `#{Macro.to_string(unquote(module))}`"

          unquote(events)
        end
      end

    contract_binary_ast =
      quote context: module do
        def __contract_binary__, do: unquote(contract_binary)
      end

    [contract_binary_ast, constructor_ast | functions_ast] ++ [events_module_ast]
  end

  @doc false
  @spec perform_action(action(), map, Keyword.t(), Keyword.t()) ::
          {:ok, [term]}
          | {:ok, Ethers.Types.t_hash()}
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
  defp generate_method(%{selector: %ABI.FunctionSelector{type: :constructor} = selector}, mod) do
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

    quote context: mod, location: :keep do
      @doc """
      Prepares contract constructor values.

      To deploy a contracts see `Ethers.deploy/3`.

      ## Parameters
      #{unquote(document_types(selector.types, selector.input_names))}
      """
      @spec constructor(unquote_splicing(func_input_types)) :: binary()
      def constructor(unquote_splicing(func_args)) do
        args =
          unquote(func_args)
          |> Enum.zip(unquote(Macro.escape(selector.types)))
          |> Enum.map(fn {arg, type} -> Ethers.Utils.prepare_arg(arg, type) end)

        unquote(Macro.escape(selector))
        |> ABI.encode(args)
        |> Ethers.Utils.hex_encode(false)
      end
    end
  end

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
          |> Enum.map(&get_argument_name_ast/1)
        else
          # Invalid input name length, fallback to generated argument names
          args
        end
      end)

    func_input_types =
      selector.types
      |> Enum.map(&Ethers.Types.to_elixir_type/1)

    func_return_typespec =
      selector.returns
      |> Enum.map(&Ethers.Types.to_elixir_type/1)
      |> then(fn
        [] -> []
        list -> Enum.reduce(list, &{:|, [], [&1, &2]})
      end)

    default_action = get_default_action(selector)

    overrides = get_overrides(mod, has_other_arities)

    defaults =
      %{to: default_address}
      |> Map.reject(fn {_, v} -> is_nil(v) end)
      |> Macro.escape()

    quote context: mod, location: :keep do
      @doc """
      Executes `#{unquote(human_signature(selector))}` on the contract.

      ## Parameters
      #{unquote(document_types(selector.types, selector.input_names))}
      - overrides: Overrides and options for the call.
        - `to`: The address of the recipient contract. (**Required**)
        - `action`: Type of action for this function (`:call`, `:send` or `:prepare`) Default: `#{inspect(unquote(default_action))}`.
        - `rpc_opts`: Options to pass to the RCP client e.g. `:url`.

      ## Return Types
      #{unquote(document_types(selector.returns))}
      """
      @spec unquote(name)(unquote_splicing(func_input_types), Keyword.t()) ::
              {:ok, [unquote(func_return_typespec)]}
              | {:ok, Ethers.Types.t_hash()}
              | {:ok, Ethers.Contract.t_function_output()}
      def unquote(name)(unquote_splicing(func_args), unquote(overrides)) do
        args =
          unquote(func_args)
          |> Enum.zip(unquote(Macro.escape(selector.types)))
          |> Enum.map(fn {arg, type} -> Ethers.Utils.prepare_arg(arg, type) end)

        data =
          unquote(Macro.escape(selector))
          |> ABI.encode(args)
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

    func_input_typespec =
      indexed_types
      |> Enum.map(&Ethers.Types.to_elixir_type/1)

    selector = %{selector | returns: non_indexed_types}

    topic_0 =
      selector
      |> ABI.FunctionSelector.encode()
      |> keccak_module().hash_256()
      |> Ethers.Utils.hex_encode()

    overrides = get_overrides(mod, has_other_arities)

    quote context: mod, location: :keep do
      @doc """
      Create event filter for `#{unquote(human_signature(selector))}` 

      For each indexed parameter you can either pass in the value you want to 
      filter or `nil` if you don't want to filter.

      ## Parameters
      #{unquote(document_types(indexed_types, selector.input_names))}
      - overrides: Overrides and options for the call. (**Required**)
        - `address`: The address or list of addresses of the originating contract(s). (**Optional**)

      ## Event Data Types
      #{unquote(document_types(selector.types, selector.input_names))}
      """
      @spec unquote(name)(unquote_splicing(func_input_typespec), Keyword.t()) ::
              {:ok, Ethers.Contract.t_event_output()}
      def unquote(name)(unquote_splicing(func_args), unquote(overrides)) do
        address = Keyword.get(overrides, :address, unquote(default_address))

        sub_topics =
          Enum.zip(unquote(Macro.escape(selector.types)), unquote(func_args))
          |> Enum.map(fn
            {_, nil} ->
              nil

            {type, value} ->
              value
              |> Ethers.Utils.prepare_arg(type)
              |> List.wrap()
              |> ABI.TypeEncoder.encode([type])
              |> Ethers.Utils.hex_encode()
          end)

        {:ok,
         %{
           topics: [unquote(topic_0) | sub_topics],
           address: address,
           selector: unquote(Macro.escape(selector))
         }}
      end
    end
  end
end
