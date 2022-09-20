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

  ## Valid parameters
  - abi: Used to pass in the encoded/decoded json ABI of contract.
  - abi_file: Used to pass in the file path to the json ABI of contract.
  """

  @type t_function_output :: %{data: binary, selector: ABI.FunctionSelector.t()}

  @doc "Gaurd for validating the response for eth_call"
  defguard valid_result(bin) when byte_size(bin) > 2

  defmacro __using__(opts) do
    {opts, _} = Code.eval_quoted(opts, [], __CALLER__)
    {:ok, abi} = read_abi(opts)

    abi
    |> ABI.parse_specification()
    |> Enum.reject(&is_nil(&1.function))
    |> Enum.map(&generate_method(&1, __CALLER__.module))
  end

  @doc """
  Makes an eth_call to with the given data and overrides, Than parses
  the response using the selector in the params

  ## Examples

      iex> Elixirium.Contract.ERC20.total_supply() |> Elixirium.Contract.call(to: "0xa0b...ef6")
      {:ok, [100000000000000]}
  """
  @spec call(map, Keyword.t()) :: {:ok, [...]} | {:error, term()}
  def call(%{data: _, selector: selector} = params, opts_and_overrides \\ []) do
    {block, overrides} = Keyword.pop(opts_and_overrides, :block, "latest")

    params =
      overrides
      |> Enum.into(params)
      |> Map.drop([:selector, :rpc_opts])

    {rpc_client, rpc_opts} = rpc_info(overrides)

    with {:ok, resp} when valid_result(resp) <- rpc_client.eth_call(params, block, rpc_opts),
         {:ok, resp_bin} <- Elixirium.Utils.hex_decode(resp) do
      {:ok, ABI.decode(selector, resp_bin, :output)}
    else
      {:ok, "0x"} ->
        {:error, :unknown}

      {:error, cause} ->
        {:error, cause}
    end
  end

  @doc """
  Makes an eth_send to with the given data and overrides, Then returns the
  transaction binary.

  ## Examples

      iex> Elixirium.Contract.ERC20.transfer("0xff0...ea2", 1000) |> Elixirium.Contract.send(to: "0xa0b...ef6")
      {:ok, transaction_bin}
  """
  @spec send(map, Keyword.t()) :: {:ok, String.t()} | {:error, term()}
  def send(%{data: _} = params, overrides \\ []) do
    params =
      overrides
      |> Enum.into(params)
      |> Map.drop([:selector, :rpc_opts])

    {rpc_client, rpc_opts} = rpc_info(overrides)

    with {:ok, resp} when valid_result(resp) <- rpc_client.eth_call(params, rpc_opts),
         {:ok, tx} when valid_result(tx) <- rpc_client.eth_send_transaction(params, rpc_opts) do
      {:ok, tx}
    else
      {:ok, "0x"} ->
        {:error, :unknown}

      {:error, cause} ->
        {:error, cause}
    end
  end

  @spec generate_method(ABI.FunctionSelector.t(), atom()) :: any()
  defp generate_method(selector, mod) do
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

    quote do
      @doc """
      #{unquote(name)}

      ## Parameters
      #{unquote(document_types(selector.types, selector.input_names))}

      ## Returns
      #{unquote(document_types(selector.returns))}
      """
      @spec unquote(name)(unquote_splicing(func_input_types)) ::
              Elixirium.Contract.t_function_output()
      def unquote(name)(unquote_splicing(func_args)) do
        data =
          unquote(Macro.escape(selector))
          |> ABI.encode([unquote_splicing(func_args)])
          |> Elixirium.Utils.hex_encode()

        %{
          data: data,
          selector: unquote(Macro.escape(selector))
        }
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
    if length(types) == length(names) do
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
end
