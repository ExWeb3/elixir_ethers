defmodule Ethers.RpcClient.EthereumexHttpClient do
  @moduledoc false

  alias Ethers.RpcClient.Adapter

  @behaviour Ethers.RpcClient.Adapter

  @exclude_delegation [:eth_get_logs]

  for {func, arity} <- Adapter.behaviour_info(:callbacks), func not in @exclude_delegation do
    args = Macro.generate_arguments(arity - 1, __MODULE__)

    @impl true
    def unquote(func)(unquote_splicing(args), opts \\ []) do
      apply(Ethereumex.HttpClient, unquote(func), [unquote_splicing(args), opts])
    end
  end

  @impl true
  def eth_get_logs(params, opts \\ []) do
    params
    |> replace_key(:from_block, :fromBlock)
    |> replace_key(:to_block, :toBlock)
    |> Ethereumex.HttpClient.eth_get_logs(opts)
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
