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

  alias Ethers.Event
  alias Ethers.EventFilter
  alias Ethers.ExecutionError
  alias Ethers.TxData
  alias Ethers.Types
  alias Ethers.Utils

  @option_keys [:rpc_client, :rpc_opts]
  @hex_decode_post_process [:estimate_gas, :current_gas_price, :current_block_number]

  defguardp valid_result(bin) when bin != "0x"

  @doc """
  Returns the current gas price from the RPC API
  """
  @spec current_gas_price(Keyword.t()) :: {:ok, non_neg_integer()}
  def current_gas_price(overrides \\ []) do
    {opts, _overrides} = Keyword.split(overrides, @option_keys)

    {rpc_client, rpc_opts} = get_rpc_client(opts)

    rpc_client.eth_gas_price(rpc_opts)
    |> post_process(nil, :current_gas_price)
  end

  @doc """
  Returns the current block number of the blockchain.
  """
  @spec current_block_number(Keyword.t()) :: {:ok, non_neg_integer()} | {:error, term()}
  def current_block_number(overrides \\ []) do
    {opts, _overrides} = Keyword.split(overrides, @option_keys)

    {rpc_client, rpc_opts} = get_rpc_client(opts)

    rpc_client.eth_block_number(rpc_opts)
    |> post_process(nil, :current_block_number)
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

    {rpc_client, rpc_opts} = get_rpc_client(opts)

    with {:ok, params} <- Utils.maybe_add_gas_limit(params, opts) do
      rpc_client.eth_send_transaction(params, rpc_opts)
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
    {rpc_client, rpc_opts} = get_rpc_client(opts)

    rpc_client.eth_get_transaction_receipt(tx_hash, rpc_opts)
    |> post_process(tx_hash, :deployed_address)
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
  {:ok, 100000000000000}
  ```
  """
  @spec call(TxData.t(), Keyword.t()) :: {:ok, any()} | {:error, term()}
  def call(params, overrides \\ [])

  def call(tx_data, overrides) do
    {opts, overrides} = Keyword.split(overrides, @option_keys)

    {rpc_client, rpc_opts} = get_rpc_client(opts)

    with {:ok, tx_params, block} <- pre_process(tx_data, overrides, :call, opts) do
      rpc_client.eth_call(tx_params, block, rpc_opts)
      |> post_process(tx_data, :call)
    end
  end

  @doc """
  Same as `Ethers.call/2` but raises on error.
  """
  @spec call!(TxData.t(), Keyword.t()) :: any() | no_return()
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
  @spec send(map() | TxData.t(), Keyword.t()) :: {:ok, String.t()} | {:error, term()}
  def send(tx_data, overrides \\ []) do
    {opts, overrides} = Keyword.split(overrides, @option_keys)

    {rpc_client, rpc_opts} = get_rpc_client(opts)

    with {:ok, tx_params} <- pre_process(tx_data, overrides, :send, opts) do
      rpc_client.eth_send_transaction(tx_params, rpc_opts)
      |> post_process(tx_data, :send)
    end
  end

  @doc """
  Same as `Ethers.send/2` but raises on error.
  """
  @spec send!(map() | TxData.t(), Keyword.t()) :: String.t() | no_return()
  def send!(tx_data, overrides \\ []) do
    case Ethers.send(tx_data, overrides) do
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
  def estimate_gas(tx_data, overrides \\ []) do
    {opts, overrides} = Keyword.split(overrides, @option_keys)

    {rpc_client, rpc_opts} = get_rpc_client(opts)

    with {:ok, tx_params} <- pre_process(tx_data, overrides, :estimate_gas, opts) do
      rpc_client.eth_estimate_gas(tx_params, rpc_opts)
      |> post_process(tx_data, :estimate_gas)
    end
  end

  @doc """
  Same as `Ethers.estimate_gas/2` but raises on error.
  """
  @spec estimate_gas!(map(), Keyword.t()) :: non_neg_integer() | no_return()
  def estimate_gas!(tx_data, overrides \\ []) do
    case estimate_gas(tx_data, overrides) do
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
  def get_logs(event_filter, overrides \\ []) do
    {opts, overrides} = Keyword.split(overrides, @option_keys)

    {rpc_client, rpc_opts} = get_rpc_client(opts)

    with {:ok, log_params} <- pre_process(event_filter, overrides, :get_logs, opts) do
      rpc_client.eth_get_logs(log_params, rpc_opts)
      |> post_process(event_filter, :get_logs)
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
  @spec keccak_module() :: atom()
  def keccak_module, do: Application.get_env(:ethers, :keccak_module, ExKeccak)

  @doc false
  @spec json_module() :: atom()
  def json_module, do: Application.get_env(:ethers, :json_module, Jason)

  @doc false
  @spec rpc_client() :: atom()
  def rpc_client, do: Application.get_env(:ethers, :rpc_client, Ethereumex.HttpClient)

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

  defp pre_process(tx_data, overrides, _action = :call, _opts) do
    {block, overrides} = Keyword.pop(overrides, :block, "latest")

    block =
      case block do
        number when is_integer(number) -> Utils.integer_to_hex(number)
        v -> v
      end

    tx_params = TxData.to_map(tx_data, overrides)

    case check_params(tx_params, :call) do
      :ok -> {:ok, tx_params, block}
      err -> err
    end
  end

  defp pre_process(tx_data, overrides, action = :send, opts) do
    tx_params = TxData.to_map(tx_data, overrides)

    with :ok <- check_params(tx_params, action),
         {:ok, tx_params} <- Utils.maybe_add_gas_limit(tx_params, opts) do
      {:ok, tx_params}
    end
  end

  defp pre_process(tx_data, overrides, action = :estimate_gas, _opts) do
    tx_params = TxData.to_map(tx_data, overrides)

    with :ok <- check_params(tx_params, action) do
      {:ok, tx_params}
    end
  end

  defp pre_process(event_filter, overrides, :get_logs, _opts) do
    log_params =
      event_filter
      |> EventFilter.to_map(overrides)
      |> ensure_hex_value(:fromBlock)
      |> ensure_hex_value(:toBlock)

    {:ok, log_params}
  end

  defp post_process({:ok, resp}, tx_data, :call) when valid_result(resp) do
    tx_data.selector
    |> ABI.decode(Ethers.Utils.hex_decode!(resp), :output)
    |> Enum.zip(tx_data.selector.returns)
    |> Enum.map(fn {return, type} -> Utils.human_arg(return, type) end)
    |> case do
      [element] -> {:ok, element}
      elements -> {:ok, elements}
    end
  end

  defp post_process({:ok, tx_hash}, _tx_data, _action = :send) when valid_result(tx_hash),
    do: {:ok, tx_hash}

  defp post_process({:ok, gas_hex}, _tx_data, action)
       when valid_result(gas_hex) and action in @hex_decode_post_process do
    Utils.hex_to_integer(gas_hex)
  end

  defp post_process({:ok, resp}, event_filter, :get_logs) when is_list(resp) do
    logs = Enum.map(resp, &Event.decode(&1, event_filter.selector))

    {:ok, logs}
  end

  defp post_process({:ok, resp}, _event_filter, :get_logs) do
    {:ok, resp}
  end

  defp post_process({:ok, %{"contractAddress" => contract_address}}, _tx_hash, :deployed_address)
       when not is_nil(contract_address),
       do: {:ok, contract_address}

  defp post_process({:ok, nil}, _tx_hash, :deployed_address),
    do: {:error, :transaction_not_found}

  defp post_process({:ok, _}, _tx_hash, :deployed_address),
    do: {:error, :no_contract_address}

  defp post_process({:ok, _}, _tx_data, _action),
    do: {:error, :unknown}

  defp post_process({:error, cause}, _tx_data, _action),
    do: {:error, cause}

  defp ensure_hex_value(params, key) do
    case Map.get(params, key) do
      v when is_integer(v) -> %{params | key => Utils.integer_to_hex(v)}
      _ -> params
    end
  end

  defp check_to_address(%{to: to_address}, _action) when is_binary(to_address), do: :ok
  defp check_to_address(%{to: nil}, action) when action in [:send, :estimate_gas], do: :ok
  defp check_to_address(_params, _action), do: {:error, :no_to_address}

  defp check_params(params, action) do
    check_to_address(params, action)
  end
end
