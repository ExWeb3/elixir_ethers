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
  - `default_address`: Default contract deployed address. Can be overridden with `:to` option in every function.

  ## Execution Options
  These can be specified for all the actions by contracts.

  - `action`: Type of action for this function. Here are available values.
    - `:call` uses `eth_call` to call the function and get the result. Will not change blockchain state or cost gas.
    - `:send` uses `eth_sendTransaction` to call
    - `:estimate_gas` uses `eth_estimateGas` to estimate the gas usage of this transaction.
    - `:prepare` only prepares the `data` needed to make a transaction. Useful for Multicall.
  - `from`: The address of the wallet making this transaction. The private key should be loaded in the rpc server (For example: go-ethereum). Must be in `"0x..."` format.
  - `gas`: The gas limit for your transaction.
  - `rpc_client`: The RPC module implementing Ethereum JSON RPC functions. Defaults to `Ethereumex.HttpClient`
  - `rpc_opts`: Options to pass to the RCP client e.g. `:url`.
  - `to`: The address of the recipient contract. It will be defaulted to `default_address` if it was specified in Contract otherwise is required. Must be in `"0x..."` format.
  """

  require Ethers.ContractHelpers
  import Ethers.ContractHelpers
  alias Ethers.Result

  @type action :: :call | :send | :prepare
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
          has_other_arities: Enum.count(function_selectors, &(&1.function == function)) > 1
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

  @doc false
  @spec perform_action(action(), map, Keyword.t(), Keyword.t()) ::
          {:ok, Result.t()}
          | {:error, term()}
  def perform_action(action, params, overrides \\ [], rpc_opts \\ [])

  def perform_action(:call, params, overrides, rpc_opts),
    do: Ethers.RPC.call(params, overrides, rpc_opts)

  def perform_action(:send, params, overrides, rpc_opts),
    do: Ethers.RPC.send(params, overrides, rpc_opts)

  def perform_action(:estimate_gas, params, overrides, rpc_opts),
    do: Ethers.RPC.estimate_gas(params, overrides, rpc_opts)

  def perform_action(:prepare, params, overrides, _rpc_opts),
    do: Ethers.RPC.prepare_params(params, overrides)

  def perform_action(action, _params, _overrides, _rpc_opts),
    do: raise("#{__MODULE__} Invalid action: #{inspect(action)}")

  ## Helpers

  @spec generate_method(map(), atom()) :: any()
  defp generate_method(%{selector: %ABI.FunctionSelector{type: :constructor} = selector}, mod) do
    func_args = generate_arguments(mod, selector.types, selector.input_names)

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
           has_other_arities: has_other_arities
         } = _function_data,
         mod
       ) do
    name =
      selector.function
      |> Macro.underscore()
      |> String.to_atom()

    bang_fun_name = String.to_atom("#{name}!")

    func_args = generate_arguments(mod, selector.types, selector.input_names)

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

    quote context: mod, location: :keep do
      @doc """
      Executes `#{unquote(human_signature(selector))}` on the contract.

      Default action for this function is `#{inspect(unquote(default_action))}`.
      To override default action see Execution Options in `Ethers.Contract`.

      ## Parameters
      #{unquote(document_types(selector.types, selector.input_names))}
      - overrides: Overrides and options for the call. See Execution Options in `Ethers.Contract`.

      ## Return Types
      #{unquote(document_types(selector.returns))}
      """
      @spec unquote(name)(unquote_splicing(func_input_types), Keyword.t()) ::
              {:ok, [unquote(func_return_typespec)]}
              | {:ok, Ethers.Types.t_hash()}
              | {:ok, Ethers.Contract.t_function_output()}
              | {:error, term()}
      def unquote(name)(unquote_splicing(func_args), unquote(overrides)) do
        args =
          unquote(func_args)
          |> Enum.zip(unquote(Macro.escape(selector.types)))
          |> Enum.map(fn {arg, type} -> Ethers.Utils.prepare_arg(arg, type) end)

        data =
          unquote(Macro.escape(selector))
          |> ABI.encode(args)
          |> Ethers.Utils.hex_encode()

        params = %{
          data: data,
          selector: unquote(Macro.escape(selector)),
          to: __MODULE__.default_address()
        }

        {rpc_opts, overrides} = Keyword.pop(overrides, :rpc_opts, [])
        {action, overrides} = Keyword.pop(overrides, :action, unquote(default_action))

        Ethers.Contract.perform_action(action, params, overrides, rpc_opts)
      end

      @doc """
      Same as `#{unquote(name)}/#{unquote(Enum.count(func_args) + 1)}` but raises `Ethers.ExecutionError` on errors.
      """
      @spec unquote(bang_fun_name)(unquote_splicing(func_input_types), Keyword.t()) ::
              [unquote(func_return_typespec)]
              | Ethers.Types.t_hash()
              | Ethers.Contract.t_function_output()
              | no_return
      def unquote(bang_fun_name)(unquote_splicing(func_args), unquote(overrides)) do
        case unquote(name)(unquote_splicing(func_args), overrides) do
          {:ok, result} ->
            result

          {:error, reason} ->
            raise Ethers.ExecutionError,
              error: reason,
              function: unquote(name),
              args: unquote(func_args)
        end
      end
    end
  end

  defp generate_event_filter(
         %{
           selector: %ABI.FunctionSelector{type: :event} = selector,
           has_other_arities: has_other_arities
         } = _function_data,
         mod
       ) do
    name =
      selector.function
      |> Macro.underscore()
      |> String.to_atom()

    func_args = generate_arguments(mod, selector.inputs_indexed, selector.input_names)

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
      |> Ethers.keccak_module().hash_256()
      |> Ethers.Utils.hex_encode()

    overrides = get_overrides(mod, has_other_arities)

    quote context: mod, location: :keep do
      @doc """
      Create event filter for `#{unquote(human_signature(selector))}` 

      For each indexed parameter you can either pass in the value you want to 
      filter or `nil` if you don't want to filter.

      ## Parameters
      #{unquote(document_types(indexed_types, selector.input_names))}
      - overrides: Overrides and options for the call.
        - `address`: The address or list of addresses of the originating contract(s). (**Optional**)

      ## Event Data Types
      #{unquote(document_types(selector.types, selector.input_names))}
      """
      @spec unquote(name)(unquote_splicing(func_input_typespec), Keyword.t()) ::
              Ethers.Contract.t_event_output()
      def unquote(name)(unquote_splicing(func_args), unquote(overrides)) do
        address = Keyword.get(overrides, :address, __MODULE__.default_address())

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

        %{
          topics: [unquote(topic_0) | sub_topics],
          address: address,
          selector: unquote(Macro.escape(selector))
        }
      end
    end
  end
end
