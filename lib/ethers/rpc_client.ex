defmodule Ethers.RpcClient do
  @doc false
  @spec rpc_client() :: atom()
  def rpc_client,
    do: Application.get_env(:ethers, :rpc_client, Ethers.RpcClient.EthereumexHttpClient)

  @doc false
  @spec get_rpc_client(Keyword.t()) :: {atom(), Keyword.t()}
  def get_rpc_client(opts) do
    module =
      case Keyword.fetch(opts, :rpc_client) do
        {:ok, module} when is_atom(module) -> module
        :error -> Ethers.rpc_client()
      end

    {module, Keyword.get(opts, :rpc_opts, [])}
  end
end
