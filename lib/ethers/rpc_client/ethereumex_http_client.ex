defmodule Ethers.RpcClient.EthereumexHttpClient do
  @moduledoc false

  alias Ethers.RpcClient.Adapter

  @behaviour Ethers.RpcClient.Adapter

  # Callbacks implemented manually below instead of being delegated verbatim, either
  # because Ethereumex does not expose the RPC method or because it needs param mapping.
  @manual_implementations [
    batch_request: 2,
    eth_call: 4,
    eth_create_access_list: 3,
    eth_estimate_gas: 4,
    eth_get_logs: 2
  ]

  for {func, arity} <- Adapter.behaviour_info(:callbacks),
      {func, arity} not in @manual_implementations do
    args = Macro.generate_arguments(arity - 1, __MODULE__)

    @impl true
    def unquote(func)(unquote_splicing(args), opts \\ []) do
      apply(Ethereumex.HttpClient, unquote(func), [unquote_splicing(args), opts])
    end
  end

  @impl true
  def batch_request(methods, opts \\ []) do
    # Build the batch from RPC method names through Ethereumex's generic request/3
    # instead of Ethereumex.HttpClient.batch_request/2 (which dispatches to named
    # functions), so every method this adapter supports is also batchable
    methods
    |> Enum.with_index(1)
    |> Enum.map(fn {{method, params}, id} ->
      method
      |> rpc_method_name()
      |> Ethereumex.HttpClient.request(params, batch: true)
      |> Map.put("id", id)
    end)
    |> Ethereumex.Config.json_module().encode!()
    |> Ethereumex.HttpClient.post_request(opts)
  end

  @impl true
  def eth_call(params, block, state_overrides, opts) do
    Ethereumex.HttpClient.request("eth_call", [params, block, state_overrides], opts)
  end

  @impl true
  def eth_create_access_list(params, block, opts \\ []) do
    Ethereumex.HttpClient.request("eth_createAccessList", [params, block], opts)
  end

  @impl true
  def eth_estimate_gas(params, block, state_overrides, opts) do
    Ethereumex.HttpClient.request("eth_estimateGas", [params, block, state_overrides], opts)
  end

  @impl true
  def eth_get_logs(params, opts \\ []) do
    params
    |> replace_key(:from_block, :fromBlock)
    |> replace_key(:to_block, :toBlock)
    |> Ethereumex.HttpClient.eth_get_logs(opts)
  end

  # Converts a snake_case method atom to the camelCase JSON-RPC method name, keeping
  # the namespace prefix: :eth_create_access_list -> "eth_createAccessList"
  defp rpc_method_name(method) when is_atom(method) do
    case method |> Atom.to_string() |> String.split("_") do
      [namespace] ->
        namespace

      [namespace, part | parts] ->
        "#{namespace}_#{part}#{Enum.map_join(parts, &String.capitalize/1)}"
    end
  end

  defp replace_key(map, ethers_key, ethereumex_key) do
    case Map.fetch(map, ethers_key) do
      {:ok, value} ->
        map
        |> Map.put(ethereumex_key, value)
        |> Map.delete(ethers_key)

      :error ->
        map
    end
  end
end
