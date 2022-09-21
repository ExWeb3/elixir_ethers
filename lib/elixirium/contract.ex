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
          @moduledoc "Events for #{unquote(module)}"

          unquote(events)
        end
      end

    functions_ast =
      functions_selectors
      |> Enum.filter(&(&1.type == :function))
      |> Enum.map(&generate_method(&1, __CALLER__.module))

    [events_module_ast | functions_ast]
  end

  defguardp valid_result(bin) when bin != "0x"

  @doc """
  Makes an eth_call to with the given data and overrides, Than parses
  the response using the selector in the params

  ## Overrides
  This function accepts all of options which `Ethereumex.BaseClient.eth_send_transaction` accepts.
  Notable you can use these.

  - `:to`: Indicates recepient address. (Contract address in this case)

  ## Options
  - `:rpc_client`: The RPC Client to use. It should implement ethereum jsonRPC API. default: Ethereumex.HttpClient
  - `:rpc_opts`: Extra options to pass to rpc_client. (Like timeout, Server URL, etc.)

  ## Examples

      iex> Elixirium.Contract.ERC20.total_supply() |> Elixirium.Contract.call(to: "0xa0b...ef6")
      {:ok, [100000000000000]}
  """
  @spec call(map, Keyword.t()) :: {:ok, [...]} | {:error, term()}
  def call(params, overrides \\ [], opts \\ [])

  def call(%{data: _, selector: selector} = params, overrides, opts) do
    block = Keyword.get(opts, :block, "latest")
    {rpc_client, rpc_opts} = rpc_info(opts)

    params =
      overrides
      |> Enum.into(params)
      |> Map.drop([:selector])

    with {:has_to, true} <- {:has_to, Map.has_key?(params, :to)},
         {:ok, resp} when valid_result(resp) <- rpc_client.eth_call(params, block, rpc_opts),
         {:ok, resp_bin} <- Elixirium.Utils.hex_decode(resp) do
      {:ok, ABI.decode(selector, resp_bin, :output)}
    else
      {:ok, "0x"} ->
        {:error, :unknown}

      {:has_to, false} ->
        {:error, :no_to_address}

      {:error, cause} ->
        {:error, cause}
    end
  end

  @doc """
  Makes an eth_send to with the given data and overrides, Then returns the
  transaction binary.

  ## Overrides
  This function accepts all of options which `Ethereumex.BaseClient.eth_send_transaction` accepts.
  Notable you can use these.

  - `:to`: Indicates recepient address. (Contract address in this case)

  ## Options
  - `:rpc_client`: The RPC Client to use. It should implement ethereum jsonRPC API. default: Ethereumex.HttpClient
  - `:rpc_opts`: Extra options to pass to rpc_client. (Like timeout, Server URL, etc.)

  ## Examples

      iex> Elixirium.Contract.ERC20.transfer("0xff0...ea2", 1000) |> Elixirium.Contract.send(to: "0xa0b...ef6")
      {:ok, transaction_bin}
  """
  @spec send(map, Keyword.t()) :: {:ok, String.t()} | {:error, term()}
  def send(params, overrides \\ [], opts \\ [])

  def send(%{data: _} = params, overrides, opts) do
    {rpc_client, rpc_opts} = rpc_info(opts)

    params =
      overrides
      |> Enum.into(params)
      |> Map.drop([:selector])

    with {:has_to, true} <- {:has_to, Map.has_key?(params, :to)},
         {:ok, resp} when valid_result(resp) <- rpc_client.eth_call(params, "latest", rpc_opts),
         {:ok, tx} when valid_result(tx) <- rpc_client.eth_send_transaction(params, rpc_opts) do
      {:ok, tx}
    else
      {:ok, "0x"} ->
        {:error, :unknown}

      {:has_to, false} ->
        {:error, :no_to_address}

      {:error, cause} ->
        {:error, cause}
    end
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
            Elixirium.Contract.call(params, overrides, rpc_opts)

          {:send, overrides} ->
            Elixirium.Contract.send(params, overrides, rpc_opts)

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

        topic_0 =
          unquote(Macro.escape(selector))
          |> ABI.FunctionSelector.encode()
          |> ExKeccak.hash_256()
          |> Elixirium.Utils.hex_encode()

        topics =
          [
            topic_0,
            unquote_splicing(func_args)
          ]
          |> Enum.reject(&is_nil(&1))

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

  defp rpc_info(overrides) do
    module =
      case Keyword.fetch(overrides, :rpc_client) do
        {:ok, module} when is_atom(module) -> module
        :error -> Application.get_env(:exw3, :rpc_client, Ethereumex.HttpClient)
      end

    {module, overrides[:rpc_opts] || []}
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
