defmodule Ethers.RPC do
  @moduledoc """
  RPC Methods for interacting with the Ethereum blockchain
  """

  def eth_send_transaction(params, opts \\ []) when is_map(params) do
    {rpc_client, rpc_opts} = rpc_info(opts)

    case params do
      %{to: _to_address} ->
        rpc_client.eth_send_transaction(params, rpc_opts)

      _ ->
        {:error, :no_to_address}
    end
  end

  def eth_call(params, block, opts \\ []) when is_map(params) do
    {rpc_client, rpc_opts} = rpc_info(opts)

    case params do
      %{to: to_address} when not is_nil(to_address) ->
        rpc_client.eth_call(params, block, rpc_opts)

      _ ->
        {:error, :no_to_address}
    end
  end

  def eth_estimate_gas(params, opts \\ []) when is_map(params) do
    {rpc_client, rpc_opts} = rpc_info(opts)

    case params do
      %{to: _to_address} ->
        rpc_client.eth_estimate_gas(params, rpc_opts)

      _ ->
        {:error, :no_to_address}
    end
  end

  def eth_get_logs(params, opts \\ []) when is_map(params) do
    {rpc_client, rpc_opts} = rpc_info(opts)

    rpc_client.eth_get_logs(params, rpc_opts)
  end

  def eth_gas_price(opts \\ []) do
    {rpc_client, rpc_opts} = rpc_info(opts)

    rpc_client.eth_gas_price(rpc_opts)
  end

  def eth_get_transaction_receipt(tx_hash, opts \\ []) when is_binary(tx_hash) do
    {rpc_client, rpc_opts} = rpc_info(opts)

    rpc_client.eth_get_transaction_receipt(tx_hash, rpc_opts)
  end

  def eth_block_number(opts \\ []) do
    {rpc_client, rpc_opts} = rpc_info(opts)

    rpc_client.eth_block_number(rpc_opts)
  end

  def eth_get_block_by_number(block_number, include_details?, opts \\ []) do
    {rpc_client, rpc_opts} = rpc_info(opts)

    rpc_client.eth_get_block_by_number(block_number, include_details?, rpc_opts)
  end

  ## Helpers

  defp rpc_info(overrides) do
    module =
      case Keyword.fetch(overrides, :rpc_client) do
        {:ok, module} when is_atom(module) -> module
        :error -> Ethers.rpc_client()
      end

    {module, Keyword.get(overrides, :rpc_opts, [])}
  end
end
