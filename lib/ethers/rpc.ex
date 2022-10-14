defmodule Ethers.RPC do
  @moduledoc """
  RPC Methods for interacting with the Ethereum blockchain
  """

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

      iex> Ethers.Contract.ERC20.total_supply() |> Ethers.Contract.call(to: "0xa0b...ef6")
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
         {:ok, resp_bin} <- Ethers.Utils.hex_decode(resp) do
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

      iex> Ethers.Contract.ERC20.transfer("0xff0...ea2", 1000) |> Ethers.Contract.send(to: "0xa0b...ef6")
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

  defp rpc_info(overrides) do
    module =
      case Keyword.fetch(overrides, :rpc_client) do
        {:ok, module} when is_atom(module) -> module
        :error -> Application.get_env(:exw3, :rpc_client, Ethereumex.HttpClient)
      end

    {module, overrides[:rpc_opts] || []}
  end
end
