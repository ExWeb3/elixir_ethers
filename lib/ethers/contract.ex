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
  - `abi`: Used to pass in the encoded/decoded json ABI of contract.
  - `abi_file`: Used to pass in the file path to the json ABI of contract.
  - `default_address`: Default contract deployed address to include in the parameters. (Optional)
  """

  require Ethers.ContractHelpers
  require Logger

  import Ethers.ContractHelpers

  @type action :: :call | :send | :prepare
  @type t_function_output :: %{
          data: binary,
          to: Ethers.Types.t_address() | nil,
          selector: ABI.FunctionSelector.t()
        }
  @type t_event_output :: %{
          topics: [binary],
          address: Ethers.Types.t_address(),
          selector: ABI.FunctionSelector.t()
        }

  @default_constructor %{
    type: :constructor,
    arity: 0,
    selectors: [
      %ABI.FunctionSelector{
        function: nil,
        method_id: nil,
        type: :constructor,
        inputs_indexed: nil,
        state_mutability: nil,
        input_names: [],
        types: [],
        returns: []
      }
    ]
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
      function_selectors
      |> Enum.group_by(fn
        %{type: :event} = f ->
          {f.function, Enum.count(f.inputs_indexed, & &1), f.type}

        f ->
          {f.function, Enum.count(f.types), f.type}
      end)
      |> Enum.map(fn {{function, arity, type}, selectors} ->
        %{
          selectors: selectors,
          function: function,
          arity: arity,
          type: type
        }
      end)

    constructor_ast =
      function_selectors_with_meta
      |> Enum.find(&(&1.type == :constructor))
      |> then(&(&1 || @default_constructor))
      |> generate_method(module)

    functions_ast =
      function_selectors_with_meta
      |> Enum.filter(&(&1.type == :function and not is_nil(&1.function)))
      |> Enum.map(&generate_method(&1, module))

    events_mod_name = Module.concat(module, EventFilters)

    events =
      function_selectors_with_meta
      |> Enum.filter(&(&1.type == :event))
      |> Enum.map(&generate_event_filter(&1, module))

    events_module_ast =
      quote context: module do
        defmodule unquote(events_mod_name) do
          @moduledoc "Events for `#{Macro.to_string(unquote(module))}`"

          defdelegate default_address, to: unquote(module)
          unquote(events)
        end
      end

    extra_ast =
      quote context: module do
        def __contract_binary__, do: unquote(contract_binary)

        @doc """
        Default address of the contract. Returns `nil` if not specified.

        To specify a default address see `Ethers.Contract`
        """
        @spec default_address() :: Ethers.Types.t_address() | nil
        def default_address, do: unquote(default_address)
      end

    [extra_ast, constructor_ast | functions_ast] ++ [events_module_ast]
  end

  ## Helpers

  @spec generate_method(map(), atom()) :: any()
  defp generate_method(%{type: :constructor, arity: arity, selectors: [selector]}, mod) do
    func_args = generate_arguments(mod, arity, selector.input_names)

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
           type: :function,
           function: function,
           arity: arity,
           selectors: selectors
         } = _function_data,
         mod
       ) do
    name =
      function
      |> Macro.underscore()
      |> String.to_atom()

    aggregated_input_names = aggregate_input_names(selectors)

    func_args =
      generate_arguments(mod, arity, aggregated_input_names)

    func_input_types = generate_typespecs(selectors)

    quote context: mod, location: :keep do
      @doc """
      Executes `#{unquote(human_signature(selectors))}` on the contract.

      #{unquote(document_help_message(selectors))}

      #{unquote(document_parameters(selectors))}

      #{unquote(document_returns(selectors))}
      """
      @spec unquote(name)(unquote_splicing(func_input_types)) ::
              Ethers.Contract.t_function_output()
      def unquote(name)(unquote_splicing(func_args)) do
        {selector, raw_args} =
          Ethers.ContractHelpers.find_selector!(
            unquote(Macro.escape(selectors)),
            unquote(func_args)
          )

        args =
          Enum.zip(raw_args, selector.types)
          |> Enum.map(fn {arg, type} -> Ethers.Utils.prepare_arg(arg, type) end)

        data =
          ABI.encode(selector, args)
          |> Ethers.Utils.hex_encode()

        %{
          data: data,
          selector: selector
        }
        |> maybe_add_to_address(__MODULE__)
      end
    end
  end

  defp generate_event_filter(
         %{
           function: function,
           type: :event,
           arity: arity,
           selectors: selectors
         } = _function_data,
         mod
       ) do
    name =
      function
      |> Macro.underscore()
      |> String.to_atom()

    aggregated_input_names = aggregate_input_names(selectors)

    func_args = generate_arguments(mod, arity, aggregated_input_names)

    func_input_typespec = generate_event_typespecs(selectors, arity)

    selectors = Enum.map(selectors, &Map.put(&1, :returns, Enum.drop(&1.types, arity)))

    quote context: mod, location: :keep do
      @doc """
      Create event filter for `#{unquote(human_signature(selectors))}` 

      For each indexed parameter you can either pass in the value you want to 
      filter or `nil` if you don't want to filter.

      #{unquote(document_parameters(selectors))}

      #{unquote(document_returns(selectors))}
      """
      @spec unquote(name)(unquote_splicing(func_input_typespec)) ::
              Ethers.Contract.t_event_output()
      def unquote(name)(unquote_splicing(func_args)) do
        {selector, raw_args} =
          Ethers.ContractHelpers.find_selector!(
            unquote(Macro.escape(selectors)),
            unquote(func_args)
          )

        topic_0 =
          selector
          |> ABI.FunctionSelector.encode()
          |> Ethers.keccak_module().hash_256()
          |> Ethers.Utils.hex_encode()

        sub_topics =
          Enum.zip(selector.types, raw_args)
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

        %{
          topics: [topic_0 | sub_topics],
          selector: selector
        }
        |> maybe_add_to_address(__MODULE__, :address)
      end
    end
  end
end
