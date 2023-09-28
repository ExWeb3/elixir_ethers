defmodule Ethers do
  @moduledoc """
  high-level module providing a convenient and efficient interface for interacting
  with the Ethereum blockchain using Elixir.

  This module offers a simple API for common Ethereum operations such as deploying contracts,
  fetching current gas prices, and querying event logs.

  ## Execution Options
  These can be specified contract functions using `Ethers.call/2`, `Ethers.send/2` or `Ethers.estimate_gas/2`
  or their equivalent bang functions.

  - `to`: The address of the recipient contract. If the contract module has a default, this will override it. Must be in `"0x..."` format.
  - `from`: The address of the wallet making this transaction. The private key should be loaded in the rpc server. Must be in `"0x..."` format.
  - `gas`: The gas limit for your transaction.
  - `rpc_client`: The RPC module implementing Ethereum JSON RPC functions. Defaults to `Ethereumex.HttpClient`
  - `rpc_opts`: Options to pass to the RCP client e.g. `:url`.
  """

  import Ethers.RPC

  alias Ethers.Types
  alias Ethers.{Event, ExecutionError, RPC, Utils}

  @internal_params [:selector]
  @option_keys [:rpc_client, :rpc_opts, :block]

  defguardp valid_result(bin) when bin != "0x"

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
  Returns the current block number of the blockchain.
  """
  @spec current_block_number(Keyword.t()) :: {:ok, non_neg_integer()} | {:error, term()}
  def current_block_number(opts \\ []) do
    with {:ok, block_number} <- RPC.eth_block_number(opts) do
      Ethers.Utils.hex_to_integer(block_number)
    end
  end

  @doc """
  Deploys a contract to the blockchain.

  This will return the transaction hash for the deployment transaction.
  To get the address of your deployed contract, use `Ethers.deployed_address/2`.

  To deploy a cotract you must have the binary related to it. It can either be a part of the ABI
  File you have or as a separate file.

  ## Parameters
  - contract_module_or_binary: Either the contract module which was already loaded or the compiled binary of the contract. The binary MUST be hex encoded.
  - contract_init: Constructor value for contract deployment. Use `CONTRACT_MODULE.constructor` function's output. If your contract does not have a constructor, you can pass an empty binary here.
  - params: Parameters for the transaction creating the contract.
  - opts: RPC and account options.
  """
  @spec deploy(atom() | binary(), binary(), Keyword.t(), Keyword.t()) ::
          {:ok, Types.t_hash()} | {:error, atom()}
  def deploy(contract_module_or_binary, contract_init, params, opts \\ [])

  def deploy(contract_module, contract_init, params, opts) when is_atom(contract_module) do
    with true <- function_exported?(contract_module, :__contract_binary__, 0),
         bin when not is_nil(bin) <- contract_module.__contract_binary__() do
      deploy(bin, contract_init, params, opts)
    else
      _error ->
        {:error, :binary_not_found}
    end
  end

  def deploy("0x" <> contract_binary, contract_init, params, opts) do
    deploy(contract_binary, contract_init, params, opts)
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
      {:ok, %{"contractAddress" => contract_address}} when not is_nil(contract_address) ->
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
  Makes an eth_call to with the given data and overrides then parses
  the response using the selector in the params

  ## Overrides and Options

  - `:to`: Indicates recepient address. (Contract address in this case)
  - `:block`: The block number or block alias. Defaults to `latest`
  - `:rpc_client`: The RPC Client to use. It should implement ethereum jsonRPC API. default: Ethereumex.HttpClient
  - `:rpc_opts`: Extra options to pass to rpc_client. (Like timeout, Server URL, etc.)

  ## Examples

  ```elixir
  Ethers.Contract.ERC20.total_supply() |> Ethers.call(to: "0xa0b...ef6")
  {:ok, [100000000000000]}
  ```
  """
  @spec call(map(), Keyword.t()) :: {:ok, [...]} | {:error, term()}
  def call(params, overrides \\ [])

  def call(%{data: _, selector: selector} = params, overrides) do
    {opts, overrides} = Keyword.split(overrides, @option_keys)

    block = Keyword.get(opts, :block, "latest")

    params =
      overrides
      |> Enum.into(params)
      |> Map.drop(@internal_params)

    case eth_call(params, block, opts) do
      {:ok, resp} when valid_result(resp) ->
        returns =
          selector
          |> ABI.decode(Ethers.Utils.hex_decode!(resp), :output)
          |> Enum.zip(selector.returns)
          |> Enum.map(fn {return, type} -> Utils.human_arg(return, type) end)

        {:ok, returns}

      {:ok, "0x"} ->
        {:error, :unknown}

      :error ->
        {:error, :hex_decode_error}

      {:error, cause} ->
        {:error, cause}
    end
  end

  @doc """
  Same as `Ethers.call/2` but raises on error.
  """
  @spec call!(map(), Keyword.t()) :: [...] | no_return()
  def call!(params, overrides \\ []) do
    case call(params, overrides) do
      {:ok, result} -> result
      {:error, reason} -> raise ExecutionError, reason
    end
  end

  @doc """
  Makes an eth_send rpc call to with the given data and overrides, Then returns the
  transaction hash.

  ## Overrides and Options

  - `:to`: Indicates recepient address. (Contract address in this case)
  - `:rpc_client`: The RPC Client to use. It should implement ethereum jsonRPC API. default: Ethereumex.HttpClient
  - `:rpc_opts`: Extra options to pass to rpc_client. (Like timeout, Server URL, etc.)

  ## Examples

  ```elixir
  Ethers.Contract.ERC20.transfer("0xff0...ea2", 1000) |> Ethers.send(to: "0xa0b...ef6")
  {:ok, _tx_hash}
  ```
  """
  @spec send(map(), Keyword.t()) :: {:ok, String.t()} | {:error, term()}
  def send(params, overrides \\ [])

  def send(params, overrides) do
    {opts, overrides} = Keyword.split(overrides, @option_keys)

    params =
      overrides
      |> Enum.into(params)
      |> Map.drop(@internal_params)

    with {:ok, params} <- Utils.maybe_add_gas_limit(params, opts),
         {:ok, tx} when valid_result(tx) <- eth_send_transaction(params, opts) do
      {:ok, tx}
    else
      {:ok, "0x"} ->
        {:error, :unknown}

      {:error, cause} ->
        {:error, cause}
    end
  end

  @doc """
  Same as `Ethers.send/2` but raises on error.
  """
  @spec send!(map(), Keyword.t()) :: String.t() | no_return()
  def send!(params, overrides \\ []) do
    case Ethers.send(params, overrides) do
      {:ok, tx_hash} -> tx_hash
      {:error, reason} -> raise ExecutionError, reason
    end
  end

  @doc """
  Makes an eth_estimate_gas rpc call with the given parameters and overrides.

  ## Overrides and Options

  - `:to`: Indicates recepient address. (Contract address in this case)
  - `:rpc_client`: The RPC Client to use. It should implement ethereum jsonRPC API. default: Ethereumex.HttpClient
  - `:rpc_opts`: Extra options to pass to rpc_client. (Like timeout, Server URL, etc.)

  ```elixir
  Ethers.Contract.ERC20.transfer("0xff0...ea2", 1000) |> Ethers.estimate_gas(to: "0xa0b...ef6")
  {:ok, 12345}
  ```
  """
  @spec estimate_gas(map(), Keyword.t()) :: {:ok, non_neg_integer()} | {:error, term()}
  def estimate_gas(params, overrides \\ []) do
    {opts, overrides} = Keyword.split(overrides, @option_keys)

    params =
      overrides
      |> Enum.into(params)
      |> Map.drop(@internal_params)

    with {:ok, gas_hex} <- eth_estimate_gas(params, opts) do
      Utils.hex_to_integer(gas_hex)
    end
  end

  @doc """
  Same as `Ethers.estimate_gas/2` but raises on error.
  """
  @spec estimate_gas!(map(), Keyword.t()) :: non_neg_integer() | no_return()
  def estimate_gas!(params, overrides \\ []) do
    case estimate_gas(params, overrides) do
      {:ok, gas} -> gas
      {:error, reason} -> raise ExecutionError, reason
    end
  end

  @doc """
  Returns the event logs with the given filter

  ## Overrides and Options

  - `:address`: Indicates event emitter contract address. (nil means all contracts)
  - `:rpc_client`: The RPC Client to use. It should implement ethereum jsonRPC API. default: Ethereumex.HttpClient
  - `:rpc_opts`: Extra options to pass to rpc_client. (Like timeout, Server URL, etc.)
  """
  @spec get_logs(map(), Keyword.t()) :: {:ok, [Event.t()]} | {:error, atom()}
  def get_logs(%{topics: _, selector: selector} = params, overrides \\ []) do
    {opts, overrides} = Keyword.split(overrides, @option_keys)

    params =
      overrides
      |> Enum.into(params)
      |> Map.drop(@internal_params)

    with {:ok, resp} when is_list(resp) <- eth_get_logs(params, opts) do
      logs = Enum.map(resp, &Event.decode(&1, selector))

      {:ok, logs}
    end
  end

  @spec get_logs!(map(), Keyword.t()) :: [Event.t()] | no_return
  def get_logs!(params, overrides \\ []) do
    case get_logs(params, overrides) do
      {:ok, logs} -> logs
      {:error, reason} -> raise ExecutionError, reason
    end
  end

  @doc false
  def keccak_module, do: Application.get_env(:ethers, :keccak_module, ExKeccak)
  @doc false
  def json_module, do: Application.get_env(:ethers, :json_module, Jason)
  @doc false
  def rpc_client, do: Application.get_env(:ethers, :rpc_client, Ethereumex.HttpClient)
end
