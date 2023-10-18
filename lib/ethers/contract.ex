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
      |> Enum.find(@default_constructor, &(&1.type == :constructor))
      |> impl(module)

    functions_ast =
      function_selectors_with_meta
      |> Enum.filter(&(&1.type == :function and not is_nil(&1.function)))
      |> Enum.map(&impl(&1, module))

    events_mod_name = Module.concat(module, EventFilters)

    events =
      function_selectors_with_meta
      |> Enum.filter(&(&1.type == :event))
      |> Enum.map(&impl(&1, module))

    events_module_ast =
      quote context: module do
        defmodule unquote(events_mod_name) do
          @moduledoc "Events for `#{Macro.to_string(unquote(module))}`"

          defdelegate __default_address__, to: unquote(module)
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
        @spec __default_address__() :: Ethers.Types.t_address() | nil
        def __default_address__, do: unquote(default_address)
      end

    [extra_ast, constructor_ast | functions_ast] ++ [events_module_ast]
  end

  ## Helpers

  defp impl(%{type: :constructor, selectors: [selector]} = abi, mod) do
    func_args = generate_arguments(mod, abi.arity, selector.input_names)

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

  defp impl(%{type: :function} = abi, mod) do
    name =
      abi.function
      |> Macro.underscore()
      |> String.to_atom()

    aggregated_input_names = aggregate_input_names(abi.selectors)

    func_args =
      generate_arguments(mod, abi.arity, aggregated_input_names)

    func_input_types = generate_typespecs(abi.selectors)

    quote context: mod, location: :keep do
      @doc """
      Executes `#{unquote(human_signature(abi.selectors))}` on the contract.

      #{unquote(document_help_message(abi.selectors))}

      #{unquote(document_parameters(abi.selectors))}

      #{unquote(document_returns(abi.selectors))}
      """
      @spec unquote(name)(unquote_splicing(func_input_types)) :: Ethers.TxData.t()
      def unquote(name)(unquote_splicing(func_args)) do
        {selector, raw_args} =
          find_selector!(unquote(Macro.escape(abi.selectors)), unquote(func_args))

        args =
          Enum.zip(raw_args, selector.types)
          |> Enum.map(fn {arg, type} -> Ethers.Utils.prepare_arg(arg, type) end)

        ABI.encode(selector, args)
        |> Ethers.Utils.hex_encode()
        |> Ethers.TxData.new(selector, __default_address__())
      end
    end
  end

  defp impl(%{type: :event} = abi, mod) do
    name =
      abi.function
      |> Macro.underscore()
      |> String.to_atom()

    aggregated_input_names = aggregate_input_names(abi.selectors)

    func_args = generate_arguments(mod, abi.arity, aggregated_input_names)

    func_typespec = generate_event_typespecs(abi.selectors, abi.arity)

    quote context: mod, location: :keep do
      @doc """
      Create event filter for `#{unquote(human_signature(abi.selectors))}` 

      For each indexed parameter you can either pass in the value you want to 
      filter or `nil` if you don't want to filter.

      #{unquote(document_parameters(abi.selectors))}

      #{unquote(document_returns(abi.selectors))}
      """
      @spec unquote(name)(unquote_splicing(func_typespec)) :: Ethers.EventFilter.t()
      def unquote(name)(unquote_splicing(func_args)) do
        {selector, raw_args} =
          find_selector!(unquote(Macro.escape(abi.selectors)), unquote(func_args))

        encode_event_topics(selector, raw_args)
        |> Ethers.EventFilter.new(selector, __default_address__())
      end
    end
  end
end
