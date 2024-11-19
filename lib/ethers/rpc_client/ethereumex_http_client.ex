defmodule Ethers.RpcClient.EthereumexHttpClient do
  @behaviour Ethers.RpcClient.Adapter

  @exclude_delegation [:eth_get_logs]

  for {func, arity} <- Ethers.RpcClient.Adapter.behaviour_info(:callbacks),
      func not in @exclude_delegation do
    args = Macro.generate_arguments(arity, __MODULE__)
    @impl true
    def unquote(func)(unquote_splicing(args)) do
      apply(Ethereumex.HttpClient, unquote(func), [unquote_splicing(args)])
    end
  end

  @impl true
  def eth_get_logs(params, opts) do
    params
    |> replace_key(:from_block, :fromBlock)
    |> replace_key(:to_block, :toBlock)
    |> Ethereumex.HttpClient.eth_get_logs(opts)
  end

  defp replace_key(map, old_key, new_key) do
    case Map.fetch(map, old_key) do
      {:ok, value} ->
        map
        |> Map.put(new_key, value)
        |> Map.delete(old_key)

      :error ->
        map
    end
  end
end
