defmodule Ethers.RpcClient do
  @moduledoc false

  @doc false
  @spec rpc_client() :: atom()
  def rpc_client do
    case Application.get_env(:ethers, :rpc_client, Ethereumex.HttpClient) do
      Ethereumex.HttpClient -> Ethers.RpcClient.EthereumexHttpClient
      module when is_atom(module) -> module
      _ -> raise ArgumentError, "Invalid ethers configuration. :rpc_client must be a module"
    end
  end

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
