defmodule Ethers do
  @moduledoc """
  high-level module providing a convenient and efficient interface for interacting
  with the Ethereum blockchain using Elixir.

  This module offers a simple API for common Ethereum operations such as deploying contracts,
  estimating gas, fetching current gas prices, and querying event logs.
  """

  alias Ethers.Types
  alias Ethers.{Event, RPC, Utils}

  @doc """
  Returns the current gas price from the RPC API
  """
  @spec current_gas_price() :: {:ok, non_neg_integer()}
  def current_gas_price do
    with {:ok, price_hex} <- RPC.eth_gas_price() do
      Ethers.Utils.hex_to_integer(price_hex)
    end
  end

  @doc """
  Deploys a contract to the blockchain.

  This will return the transaction hash for the deployment transaction.
  To get the address of your deployed contract, use `Ethers.deployed_address/2`.

  To deploy a cotract you must have the binary related to it. It can either be a part of the ABI
  File you have or as a separate file.

  ## Parameters
  - contract_module_or_binary: Either the contract module which was already loaded or the compiled binary of the contract.
  - contract_init: Constructor value for contract deployment. Use `CONTRACT_MODULE.constructor` function's output. If your contract does not have a constructor, you can pass an empty binary here.
  - params: Parameters for the transaction creating the contract.
  - opts: RPC and account options.
  """
  @spec deploy(atom() | binary(), binary(), Keyword.t(), Keyword.t()) ::
          {:ok, Types.t_hash()} | {:error, atom()}
  def deploy(contract_module_or_binary, contract_init, params, opts \\ [])

  def deploy(contract_module, contract_init, params, opts) when is_atom(contract_module) do
    cond do
      not function_exported?(contract_module, :__contract_binary__, 0) ->
        {:error, :invalid_contract_module}

      bin = contract_module.__contract_binary__() ->
        deploy(bin, contract_init, params, opts)

      true ->
        {:error, :no_contract_binary}
    end
  end

  def deploy(contract_binary, contract_init, params, opts) when is_binary(contract_binary) do
    params =
      Enum.into(params, %{
        data: "0x#{contract_binary}#{contract_init}",
        to: nil
      })

    with {:ok, params} <- Utils.maybe_add_gas_limit(params, opts) do
      RPC.eth_send_transaction(params, opts)
    end
  end

  @doc """
  Returns the address of the deployed contract if the deployment is finished and successful

  ## Parameters
  - tx_hash: Hash of the Transaction which created a contract. 
  - opts: RPC and account options.
  """
  @spec deployed_address(binary, Keyword.t()) ::
          {:ok, Types.t_address()}
          | {:error, :no_contract_address | :transaction_not_found | atom()}
  def deployed_address(tx_hash, opts \\ []) when is_binary(tx_hash) do
    case RPC.eth_get_transaction_receipt(tx_hash, opts) do
      {:ok, %{"contractAddress" => contract_address}} ->
        {:ok, contract_address}

      {:ok, nil} ->
        {:error, :transaction_not_found}

      {:ok, _} ->
        {:error, :no_contract_address}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Estimates gas for a eth_call

  ## Parameters
  - params
  - opts: RPC and account options.
  """
  @spec estimate_gas(map(), Keyword.t()) ::
          {:ok, non_neg_integer()} | {:error, :gas_estimation_failed}
  def estimate_gas(params, opts \\ []) do
    RPC.estimate_gas(params, [], opts)
  end

  @doc """
  Returns the event logs with the given filter
  """
  @spec get_logs(map(), Keyword.t(), Keyword.t()) :: {:ok, [Event.t()]} | {:error, atom()}
  def get_logs(%{topics: _, selector: selector} = params, overrides \\ [], opts \\ []) do
    params =
      overrides
      |> Enum.into(params)
      |> Map.drop([:selector])

    with {:ok, resp} when is_list(resp) <- RPC.eth_get_logs(params, opts) do
      logs = Enum.map(resp, &Event.decode(&1, selector))

      {:ok, logs}
    end
  end

  @doc false
  def keccak_module, do: Application.get_env(:ethers, :keccak_module, ExKeccak)
  @doc false
  def json_module, do: Application.get_env(:ethers, :json_module, Jason)
  @doc false
  def rpc_client, do: Application.get_env(:ethers, :rpc_client, Ethereumex.HttpClient)
end
