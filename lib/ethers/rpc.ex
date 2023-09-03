defmodule Ethers.RPC do
  @moduledoc """
  RPC Methods for interacting with the Ethereum blockchain
  """

  alias Ethers.{Result, Utils}

  defguardp valid_result(bin) when bin != "0x"

  @internal_params [:selector]

  @doc """
  Returns the prepared parameters with the overrides applied and internals removed.
  """
  @spec prepare_params(map(), map()) :: {:ok, Result.t()}
  def prepare_params(params, overrides \\ %{}) do
    params = do_prepare_params(params, overrides)
    {:ok, Result.new(params, nil, :not_estimated, nil)}
  end

  @doc """
  Makes an eth_call to with the given data and overrides, Than parses
  the response using the selector in the params

  ## Overrides
  This function accepts all of options which `Ethereumex.BaseClient.eth_send_transaction` accepts.
  Notable you can use these.

  - `:to`: Indicates recepient address. (Contract address in this case)

  ## Options
  - `:block`: The block number or block alias. Defaults to `latest`
  - `:rpc_client`: The RPC Client to use. It should implement ethereum jsonRPC API. default: Ethereumex.HttpClient
  - `:rpc_opts`: Extra options to pass to rpc_client. (Like timeout, Server URL, etc.)

  ## Examples

      iex> Ethers.Contract.ERC20.total_supply() |> Ethers.Contract.call(to: "0xa0b...ef6")
      {:ok, [100000000000000]}
  """
  @spec call(map, Keyword.t()) :: {:ok, Result.t()} | {:error, term()}
  def call(params, overrides \\ [], opts \\ [])

  def call(%{data: _, selector: selector} = params, overrides, opts) do
    block = Keyword.get(opts, :block, "latest")

    params = do_prepare_params(params, overrides)

    case eth_call(params, block, opts) do
      {:ok, resp} when valid_result(resp) ->
        returns =
          selector
          |> ABI.decode(Ethers.Utils.hex_decode!(resp), :output)
          |> Enum.zip(selector.returns)
          |> Enum.map(fn {return, type} -> Utils.human_arg(return, type) end)

        {:ok, Result.new(params, returns, :not_estimated, nil)}

      {:ok, "0x"} ->
        {:error, :unknown}

      :error ->
        {:error, :hex_decode_error}

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
  @spec send(map, Keyword.t()) :: {:ok, Result.t()} | {:error, term()}
  def send(params, overrides \\ [], opts \\ [])

  def send(params, overrides, opts) do
    params = do_prepare_params(params, overrides)

    with {:ok, params} <- Utils.maybe_add_gas_limit(params, opts),
         {:ok, tx} when valid_result(tx) <- eth_send_transaction(params, opts) do
      {:ok, Result.new(params, nil, nil, tx)}
    else
      {:ok, "0x"} ->
        {:error, :unknown}

      {:error, cause} ->
        {:error, cause}
    end
  end

  def estimate_gas(params, overrides \\ [], opts \\ []) do
    params = do_prepare_params(params, overrides)

    with {:ok, gas_hex} <- eth_estimate_gas(params, opts),
         {:ok, estimated_gas} <- Utils.hex_to_integer(gas_hex) do
      {:ok, Result.new(params, nil, estimated_gas, nil)}
    end
  end

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
    params = do_prepare_params(params)
    {rpc_client, rpc_opts} = rpc_info(opts)

    rpc_client.eth_estimate_gas(params, rpc_opts)
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

  ## Helpers

  defp rpc_info(overrides) do
    module =
      case Keyword.fetch(overrides, :rpc_client) do
        {:ok, module} when is_atom(module) -> module
        :error -> Ethers.rpc_client()
      end

    {module, Keyword.get(overrides, :rpc_opts, [])}
  end

  def do_prepare_params(params, overrides \\ %{}) do
    overrides |> Enum.into(params) |> Map.drop(@internal_params)
  end
end
