defmodule Ethers do
  @moduledoc """
  high-level module providing a convenient and efficient interface for interacting
  with the Ethereum blockchain using Elixir.

  This module offers a simple API for common Ethereum operations such as deploying contracts,
  fetching current gas prices, and querying event logs.

  ## Batching Requests

  Often you would find yourself executing different actions without dependency. These actions can
  be combined together in one JSON RPC call. This will save on the number of round trips and
  improves latency.

  Before continuing, please note that batching JSON RPC requests and using `Ethers.Multicall` are
  two different things. As a rule of thumb:

  - Use `Ethers.Multicall` if you need to make multiple contract calls and get the result
    *on the same block*.
  - Use `Ethers.batch/2` if you need to make multiple JSON RPC operations which may or may not run
    on the same block (or even be related to any specific block e.g. eth_gas_price)

  ### Make batch requests

  `Ethers.batch/2` supports all operations which the RPC module (`Ethereumex` by default)
  implements. Although some actions support pre and post processing and some are just forwarded
  to the RPC module.

  Every request passed to `Ethers.batch/2` can be in one of the following formats

  - `action_name_atom`: This only works with requests which do not require any additional data.
    e.g. `:current_gas_price` or `:net_version`.
  - `{action_name_atom, data}`: This works with all other actions which accept input data.
    e.g. `:call`, `:send_transaction` or `:get_logs`.
  - `{action_name_atom, data, overrides_keyword_list}`: Use this to override or add attributes
    to the action data. This is only accepted for these actions and will through error on others.
    - `:call`: data should be a Ethers.TxData struct and overrides are accepted.
    - `:estimate_gas`: data should be a Ethers.TxData struct or a map and overrides are accepted.
    - `:get_logs`: data should be a Ethers.EventFilter struct and overrides are accepted.
    - `:send_transaction`: data should be a Ethers.TxData struct and overrides are accepted.


  ### Example

  ```elixir
  Ethers.batch([
    :current_block_number,
    :current_gas_price,
    {:call, Ethers.Contracts.ERC20.name(), to: "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2"},
    {:send_transaction, MyContract.ping(), from: "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045"},
    {:get_logs, Ethers.Contracts.ERC20.EventFilters.approval(nil, nil)} # <- can have add overrides
  ])
  {:ok, [
    {:ok, 18539069},
    {:ok, 21221},
    {:ok, "Wrapped Ether"},
    {:ok, "0xed67b1aafdc823077166c8ee9da13c6a621d19f4d7a24a80353219c09bdac87f"},
    {:ok, [%Ethers.EventFilter{}]}
  ]}
  ```
  """

  alias Ethers.Event
  alias Ethers.EventFilter
  alias Ethers.ExecutionError
  alias Ethers.Transaction
  alias Ethers.TxData
  alias Ethers.Types
  alias Ethers.Utils

  @option_keys [:rpc_client, :rpc_opts, :signer, :signer_opts]
  @hex_decode_post_process [
    :chain_id,
    :current_block_number,
    :current_gas_price,
    :estimate_gas,
    :get_balance,
    :get_transaction_count,
    :max_priority_fee_per_gas,
    :blob_base_fee,
    :gas_price
  ]
  @rpc_actions_map %{
    call: :eth_call,
    chain_id: :eth_chain_id,
    current_block_number: :eth_block_number,
    current_gas_price: :eth_gas_price,
    estimate_gas: :eth_estimate_gas,
    gas_price: :eth_gas_price,
    get_logs: :eth_get_logs,
    get_transaction_count: :eth_get_transaction_count,
    get_transaction: :eth_get_transaction_by_hash,
    max_priority_fee_per_gas: :eth_max_priority_fee_per_gas,
    send_transaction: :eth_send_transaction,
    blob_base_fee: :eth_blob_base_fee,
    # Deprecated, kept for backward compatibility
    send: :eth_send_transaction
  }
  @send_transaction_actions [:send_transaction, :send]

  @type t_batch_request :: atom() | {atom, term()} | {atom, term(), Keyword.t()}

  defguardp valid_result(bin) when bin != "0x"

  def chain_id(opts \\ []) do
    {rpc_client, rpc_opts} = get_rpc_client(opts)

    rpc_client.eth_chain_id(rpc_opts)
    |> post_process(nil, :chain_id)
  end

  @doc """
  Same as `Ethers.chain_id/1` but raises on error.
  """
  @spec chain_id!(Keyword.t()) :: non_neg_integer() | no_return()
  def chain_id!(opts \\ []) do
    case chain_id(opts) do
      {:ok, chain_id} -> chain_id
      {:error, reason} -> raise ExecutionError, reason
    end
  end

  @doc """
  Returns the current gas price from the RPC API
  """
  @spec current_gas_price(Keyword.t()) :: {:ok, non_neg_integer()}
  def current_gas_price(opts \\ []) do
    {rpc_client, rpc_opts} = get_rpc_client(opts)

    rpc_client.eth_gas_price(rpc_opts)
    |> post_process(nil, :current_gas_price)
  end

  @doc """
  Returns the current block number of the blockchain.
  """
  @spec current_block_number(Keyword.t()) :: {:ok, non_neg_integer()} | {:error, term()}
  def current_block_number(opts \\ []) do
    {rpc_client, rpc_opts} = get_rpc_client(opts)

    rpc_client.eth_block_number(rpc_opts)
    |> post_process(nil, :current_block_number)
  end

  @doc """
  Returns the native token (ETH) balance of an account in wei.

  ## Parameters
  - account: Account which the balance is queried for.
  - overrides:
    - block: The block you want to query the balance of account in (defaults to `latest`).
    - rpc_client: The RPC module to use for this request (overrides default).
    - rpc_opts: Specific RPC options to specify for this request.
  """
  @spec get_balance(Types.t_address(), Keyword.t()) ::
          {:ok, non_neg_integer()} | {:error, term()}
  def get_balance(account, overrides \\ []) do
    {opts, overrides} = Keyword.split(overrides, @option_keys)

    {rpc_client, rpc_opts} = get_rpc_client(opts)

    with {:ok, account, block} <- pre_process(account, overrides, :get_balance, opts) do
      rpc_client.eth_get_balance(account, block, rpc_opts)
      |> post_process(nil, :get_balance)
    end
  end

  @doc """
  Same as `Ethers.get_balance/2` but raises on error.
  """
  @spec get_balance!(Types.t_address(), Keyword.t()) :: non_neg_integer() | no_return()
  def get_balance!(account, overrides \\ []) do
    case get_balance(account, overrides) do
      {:ok, balance} -> balance
      {:error, reason} -> raise ExecutionError, reason
    end
  end

  @doc """
  Returns the transaction count of an address.

  ## Parameters
  - account: Account which the transaction count is queried for.
  - overrides:
    - block: The block you want to query the transaction count in (defaults to latest).
    - rpc_client: The RPC module to use for this request (overrides default).
    - rpc_opts: Specific RPC options to specify for this request.
  """
  @spec get_transaction_count(Types.t_address(), Keyword.t()) ::
          {:ok, non_neg_integer()} | {:error, term()}
  def get_transaction_count(account, overrides \\ []) do
    {opts, overrides} = Keyword.split(overrides, @option_keys)

    {rpc_client, rpc_opts} = get_rpc_client(opts)

    with {:ok, account, block} <- pre_process(account, overrides, :get_transaction_count, opts) do
      rpc_client.eth_get_transaction_count(account, block, rpc_opts)
      |> post_process(nil, :get_transaction_count)
    end
  end

  @doc """
  Returns the native transaction (ETH) by transaction hash.

  ## Parameters
  - tx_hash: Transaction hash which the transaction is queried for.
  - overrides:
    - rpc_client: The RPC module to use for this request (overrides default).
    - rpc_opts: Specific RPC options to specify for this request.
  """
  @spec get_transaction(Types.t_hash(), Keyword.t()) ::
          {:ok, Transaction.t()} | {:error, term()}
  def get_transaction(tx_hash, opts \\ []) when is_binary(tx_hash) do
    {rpc_client, rpc_opts} = get_rpc_client(opts)

    rpc_client.eth_get_transaction_by_hash(tx_hash, rpc_opts)
    |> post_process(nil, :get_transaction)
  end

  @doc """
  Same as `Ethers.get_transaction/2` but raises on error.
  """
  @spec get_transaction!(Types.t_hash(), Keyword.t()) :: Transaction.t() | no_return()
  def get_transaction!(tx_hash, opts \\ []) do
    case get_transaction(tx_hash, opts) do
      {:ok, transaction} -> transaction
      {:error, reason} -> raise ExecutionError, reason
    end
  end

  @doc """
  Returns the receipt of a transaction by it's hash.

  ## Parameters
  - tx_hash: Transaction hash which the transaction receipt is queried for.
  - overrides:
    - rpc_client: The RPC module to use for this request (overrides default).
    - rpc_opts: Specific RPC options to specify for this request.
  """
  @spec get_transaction_receipt(Types.t_hash(), Keyword.t()) ::
          {:ok, map()} | {:error, term()}
  def get_transaction_receipt(tx_hash, opts \\ []) when is_binary(tx_hash) do
    {rpc_client, rpc_opts} = get_rpc_client(opts)

    rpc_client.eth_get_transaction_receipt(tx_hash, rpc_opts)
    |> post_process(nil, :get_transaction_receipt)
  end

  @doc """
  Same as `Ethers.get_transaction_receipt/2` but raises on error.
  """
  @spec get_transaction_receipt!(Types.t_hash(), Keyword.t()) :: map() | no_return()
  def get_transaction_receipt!(tx_hash, opts \\ []) do
    case get_transaction_receipt(tx_hash, opts) do
      {:ok, receipt} -> receipt
      {:error, reason} -> raise ExecutionError, reason
    end
  end

  @doc """
  Deploys a contract to the blockchain.

  This will return the transaction hash for the deployment transaction.
  To get the address of your deployed contract, use `Ethers.deployed_address/2`.

  To deploy a cotract you must have the binary related to it. It can either be a part of the ABI
  File you have or as a separate file.

  ## Parameters
  - contract_module_or_binary: Either the contract module which was already loaded or the compiled
  binary of the contract. The binary MUST be hex encoded.
  - overrides: A keyword list containing options and overrides.
    - `:encoded_constructor`: Hex encoded value for constructor parameters. (See `constructor`
      function of the contract module)
    - All other options from `Ethers.send_transaction/2`
  """
  @spec deploy(atom() | binary(), Keyword.t()) ::
          {:ok, Types.t_hash()} | {:error, term()}
  def deploy(contract_module_or_binary, overrides \\ [])

  def deploy(contract_module, overrides) when is_atom(contract_module) do
    case contract_module.__contract_binary__() do
      bin when is_binary(bin) ->
        deploy(bin, overrides)

      nil ->
        {:error, :binary_not_found}
    end
  end

  def deploy("0x" <> contract_binary, overrides) do
    deploy(contract_binary, overrides)
  end

  def deploy(contract_binary, overrides) when is_binary(contract_binary) do
    {opts, overrides} = Keyword.split(overrides, @option_keys)

    {rpc_client, rpc_opts} = get_rpc_client(opts)

    with {:ok, tx_params, action} <- pre_process(contract_binary, overrides, :deploy, opts) do
      apply(rpc_client, action, [tx_params, rpc_opts])
      |> post_process(tx_params, :deploy)
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
          | {:error, :no_contract_address | :transaction_not_found | term()}
  def deployed_address(tx_hash, opts \\ []) when is_binary(tx_hash) do
    {rpc_client, rpc_opts} = get_rpc_client(opts)

    rpc_client.eth_get_transaction_receipt(tx_hash, rpc_opts)
    |> post_process(tx_hash, :deployed_address)
  end

  @doc """
  Makes an eth_call to with the given `Ethers.TxData` struct and overrides. It then parses
  the response using the selector in the TxData struct.

  ## Overrides and Options

  Other than what stated below, any other option given in the overrides keyword list will be merged
  with the map that the RPC client will receive.

  - `:to`: Indicates recipient address. (Contract address in this case)
  - `:block`: The block number or block alias. Defaults to `latest`
  - `:rpc_client`: The RPC Client to use. It should implement ethereum jsonRPC API. default: Ethereumex.HttpClient
  - `:rpc_opts`: Extra options to pass to rpc_client. (Like timeout, Server URL, etc.)

  ## Return structure

  For contract functions which return a single value (e.g. `function test() returns (uint)`) this
  returns `{:ok, value}` and for the functions which return multiple values it will return
  `{:ok, [value0, value1]}` (A list).


  ## Examples

  ```elixir
  Ethers.Contract.ERC20.total_supply() |> Ethers.call(to: "0xa0b...ef6")
  {:ok, 100000000000000}
  ```
  """
  @spec call(TxData.t(), Keyword.t()) :: {:ok, [term()]} | {:ok, term()} | {:error, term()}
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
  @spec call!(TxData.t(), Keyword.t()) :: term() | no_return()
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

  Other than what stated below, any other option given in the overrides keyword list will be merged
  with the map that the RPC client will receive.

  ### Required Options
  - `:from`: The address of the account to sign the transaction with.

  ### Optional Options
  - `:access_list`: List of storage slots that this transaction accesses (optional)
  - `:chain_id`: Chain id for the transaction (defaults to chain id from RPC server).
  - `:gas_price`: (legacy only) max price willing to pay for each gas.
  - `:gas`: Gas limit for execution of this transaction.
  - `:max_fee_per_gas`: (EIP-1559 only) max fee per gas (defaults to 120% current gas price estimate).
  - `:max_priority_fee_per_gas`: (EIP-1559 only) max priority fee per gas or validator tip. (defaults to zero)
  - `:nonce`: Nonce of the transaction. (defaults to number of transactions of from address)
  - `:rpc_client`: The RPC Client to use. It should implement ethereum jsonRPC API. default: Ethereumex.HttpClient
  - `:rpc_opts`: Extra options to pass to rpc_client. (Like timeout, Server URL, etc.)
  - `:signer`: The signer module to use for signing transaction. Default is nil and will rely on the RPC server for signing.
  - `:signer_opts`: Options for signer module. See your signer docs for more details.
  - `:type`: Transaction type. Either `Ethers.Transaction.Eip1559` (default) or `Ethers.Transaction.Legacy`.
  - `:to`: Address of the contract or a receiver of this transaction. (required if TxData does not have default_address)
  - `:value`: Ether value to send with the transaction to the receiver (`from => to`).

  ## Examples

  ```elixir
  Ethers.Contract.ERC20.transfer("0xff0...ea2", 1000) |> Ethers.send_transaction(to: "0xa0b...ef6")
  {:ok, _tx_hash}
  ```
  """
  @spec send_transaction(map() | TxData.t(), Keyword.t()) :: {:ok, String.t()} | {:error, term()}
  def send_transaction(tx_data, overrides \\ []) do
    {opts, overrides} = Keyword.split(overrides, @option_keys)

    {rpc_client, rpc_opts} = get_rpc_client(opts)

    with {:ok, tx_params, action} <- pre_process(tx_data, overrides, :send_transaction, opts) do
      apply(rpc_client, action, [tx_params, rpc_opts])
      |> post_process(tx_data, :send_transaction)
    end
  end

  @deprecated "Use `Ethers.send_transaction/2` instead"
  def send(tx_data, overrides \\ []), do: send_transaction(tx_data, overrides)

  @doc """
  Same as `Ethers.send_transaction/2` but raises on error.
  """
  @spec send_transaction!(map() | TxData.t(), Keyword.t()) :: String.t() | no_return()
  def send_transaction!(tx_data, overrides \\ []) do
    case send_transaction(tx_data, overrides) do
      {:ok, tx_hash} -> tx_hash
      {:error, reason} -> raise ExecutionError, reason
    end
  end

  @deprecated "Use `Ethers.send_transaction!/2` instead"
  def send!(tx_data, overrides \\ []), do: send_transaction!(tx_data, overrides)

  @doc """
  Signs a transaction and returns the encoded signed transaction hex.

  ## Parameters
  Accepts same parameters as `Ethers.send_transaction/2`.
  """
  @spec sign_transaction(map(), Keyword.t()) :: {:ok, binary()} | {:error, term()}
  def sign_transaction(tx_data, overrides \\ []) do
    {opts, overrides} = Keyword.split(overrides, @option_keys)

    default_signer = default_signer() || Ethers.Signer.JsonRPC

    with {:ok, tx_params} <- pre_process(tx_data, overrides, :sign_transaction, opts),
         {:ok, signer} <- get_signer(opts, default_signer),
         {:ok, signed_transaction, _action} <- use_signer(tx_params, signer, opts) do
      {:ok, signed_transaction}
    end
  end

  @doc """
  Same as `Ethers.sign_transaction/2` but raises on error.
  """
  @spec sign_transaction!(map(), Keyword.t()) :: binary() | no_return()
  def sign_transaction!(tx_data, overrides \\ []) do
    case sign_transaction(tx_data, overrides) do
      {:ok, signed_transaction} -> signed_transaction
      {:error, reason} -> raise ExecutionError, reason
    end
  end

  @doc """
  Makes an eth_estimate_gas rpc call with the given parameters and overrides.

  ## Overrides and Options

  - `:to`: Indicates recipient address. (Contract address in this case)
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
  Returns the current max priority fee per gas from the RPC API
  """
  @spec max_priority_fee_per_gas(Keyword.t()) ::
          {:ok, non_neg_integer()} | {:error, reason :: term()}
  def max_priority_fee_per_gas(opts \\ []) do
    {rpc_client, rpc_opts} = get_rpc_client(opts)

    rpc_client.eth_max_priority_fee_per_gas(rpc_opts)
    |> post_process(nil, :max_priority_fee_per_gas)
  end

  @doc """
  Same as `Ethers.max_priority_fee_per_gas/1` but raises on error.
  """
  @spec max_priority_fee_per_gas!(Keyword.t()) :: non_neg_integer() | no_return()
  def max_priority_fee_per_gas!(opts \\ []) do
    case max_priority_fee_per_gas(opts) do
      {:ok, fee} -> fee
      {:error, reason} -> raise ExecutionError, reason
    end
  end

  @doc """
  Returns the current blob base fee from the RPC API
  """
  @spec blob_base_fee(Keyword.t()) ::
          {:ok, non_neg_integer()} | {:error, reason :: term()}
  def blob_base_fee(opts \\ []) do
    {rpc_client, rpc_opts} = get_rpc_client(opts)

    rpc_client.eth_blob_base_fee(rpc_opts)
    |> post_process(nil, :blob_base_fee)
  end

  @doc """
  Same as `Ethers.blob_base_fee/1` but raises on error.
  """
  @spec blob_base_fee!(Keyword.t()) :: non_neg_integer() | no_return()
  def blob_base_fee!(opts \\ []) do
    case blob_base_fee(opts) do
      {:ok, fee} -> fee
      {:error, reason} -> raise ExecutionError, reason
    end
  end

  @doc """
  Fetches the event logs with the given filter.

  ## Overrides and Options

  - `:address`: Indicates event emitter contract address. (nil means all contracts)
  - `:rpc_client`: The RPC Client to use. It should implement ethereum jsonRPC API. default: Ethereumex.HttpClient
  - `:rpc_opts`: Extra options to pass to rpc_client. (Like timeout, Server URL, etc.)
  - `:fromBlock` | `:from_block`: Minimum block number of logs to filter.
  - `:toBlock` | `:to_block`: Maximum block number of logs to filter.
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

  @doc """
  Same as `Ethers.get_logs/2` but raises on error.
  """
  @spec get_logs!(map(), Keyword.t()) :: [Event.t()] | no_return
  def get_logs!(params, overrides \\ []) do
    case get_logs(params, overrides) do
      {:ok, logs} -> logs
      {:error, reason} -> raise ExecutionError, reason
    end
  end

  @doc """
  Fetches event logs for all events in a contract's EventFilters module.

  This function is useful when you want to get all events from a contract without
  specifying a single event filter. It will automatically decode each log using
  the appropriate event selector from the EventFilters module.

  ## Parameters
  - event_filters_module: The EventFilters module (e.g. `MyContract.EventFilters`)
  - address: The contract address to filter events from (nil means all contracts)

  ## Overrides and Options

  - `:rpc_client`: The RPC Client to use. It should implement ethereum jsonRPC API. default: Ethereumex.HttpClient
  - `:rpc_opts`: Extra options to pass to rpc_client. (Like timeout, Server URL, etc.)
  - `:fromBlock` | `:from_block`: Minimum block number of logs to filter.
  - `:toBlock` | `:to_block`: Maximum block number of logs to filter.

  ## Examples

  ```elixir
  # Get all events from a contract
  {:ok, events} = Ethers.get_logs_for_contract(MyContract.EventFilters, "0x1234...")

  # Get all events with block range
  {:ok, events} = Ethers.get_logs_for_contract(MyContract.EventFilters, "0x1234...", 
    fromBlock: 1000, 
    toBlock: 2000
  )
  ```
  """
  @spec get_logs_for_contract(module(), Types.t_address() | nil, Keyword.t()) ::
          {:ok, [Event.t()]} | {:error, atom()}
  def get_logs_for_contract(event_filters_module, address, overrides \\ []) do
    overrides = Keyword.put(overrides, :address, address)
    {opts, overrides} = Keyword.split(overrides, @option_keys)

    {rpc_client, rpc_opts} = get_rpc_client(opts)

    with {:ok, log_params} <-
           pre_process(event_filters_module, overrides, :get_logs_for_contract, opts) do
      rpc_client.eth_get_logs(log_params, rpc_opts)
      |> post_process(event_filters_module, :get_logs_for_contract)
    end
  end

  @doc """
  Same as `Ethers.get_logs_for_contract/3` but raises on error.
  """
  @spec get_logs_for_contract!(module(), Types.t_address() | nil, Keyword.t()) ::
          [Event.t()] | no_return
  def get_logs_for_contract!(event_filters_module, address, overrides \\ []) do
    case get_logs_for_contract(event_filters_module, address, overrides) do
      {:ok, events} -> events
      {:error, reason} -> raise ExecutionError, reason
    end
  end

  @doc """
  Combines multiple requests and make a batch json RPC request.

  It returns `{:ok, results}` in case of success or `{:error, reason}` in case of RPC failure.

  Each action will have an entry in the results. Each entry is again a tuple and either
  `{:ok, result}` or `{:error, reason}` in case of action failure.

  Checkout `Batching Requests` sections in `Ethers` module for more examples.

  ## Parameters
  - requests: A list of requests to execute.
  - opts: RPC related options. (No account and block options are accepted in batch)

  ### Action
  An action can be in either of the following formats.

  - `{action_name_atom, action_data, action_overrides}`
  - `{action_name_atom, action_data}`
  - `action_name_atom`

  ## Examples

  ```elixir
  Ethers.batch([
    {:call, WETH.name()},
    {:call, WETH.symbol(), to: "[WETH ADDRESS]"},
    {:send_transaction, WETH.transfer("[RECEIVER]", 1000), from: "[SENDER]"},
    :current_block_number
  ])
  {:ok, [ok: "Weapped Ethereum", ok: "WETH", ok: "0xhash...", ok: 182394532]}
  ```
  """
  @spec batch([t_batch_request()], Keyword.t()) ::
          {:ok, [{:ok, term()} | {:error, term()}]} | {:error, term()}
  def batch(requests, opts \\ []) do
    {rpc_client, rpc_opts} = get_rpc_client(opts)

    requests = prepare_requests(requests)

    with rpc_requests when is_list(rpc_requests) <- prepare_batch_requests(requests, opts),
         {:ok, responses} <- rpc_client.batch_request(rpc_requests, rpc_opts) do
      results =
        responses
        |> Stream.zip(requests)
        |> Stream.map(fn {result, {action, data, _overrides}} ->
          post_process(result, data, action)
        end)
        |> Enum.to_list()

      {:ok, results}
    end
  end

  @doc """
  Same as `Ethers.batch/2` but raises on error.
  """
  @spec batch!([t_batch_request()], Keyword.t()) :: [{:ok, term()} | {:error, term()}]
  def batch!(actions, opts \\ []) do
    case batch(actions, opts) do
      {:ok, results} -> results
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
  @spec secp256k1_module() :: atom()
  def secp256k1_module, do: Application.get_env(:ethers, :secp256k1_module, ExSecp256k1)

  @doc false
  @spec rpc_client() :: atom()
  defdelegate rpc_client(), to: Ethers.RpcClient

  @doc false
  @spec get_rpc_client(Keyword.t()) :: {atom(), Keyword.t()}
  defdelegate get_rpc_client(opts), to: Ethers.RpcClient

  defp pre_process(tx_data, overrides, :call = _action, _opts) do
    {block, overrides} = Keyword.pop(overrides, :block, "latest")

    block =
      case block do
        number when is_integer(number) -> Utils.integer_to_hex(number)
        v -> v
      end

    tx_params = TxData.to_map(tx_data, overrides)

    case check_params(tx_params, :call) do
      :ok -> {:ok, Transaction.to_rpc_map(tx_params), block}
      err -> err
    end
  end

  defp pre_process(account, overrides, action, _opts)
       when action in [:get_balance, :get_transaction_count] do
    block =
      case Keyword.get(overrides, :block, "latest") do
        number when is_integer(number) -> Utils.integer_to_hex(number)
        v -> v
      end

    case account do
      "0x" <> _ -> {:ok, account, block}
      <<_::binary-20>> -> {:ok, Utils.hex_encode(account), block}
      _ -> {:error, :invalid_account}
    end
  end

  defp pre_process(contract_binary, overrides, :deploy = _action, opts) do
    {encoded_constructor, overrides} = Keyword.pop(overrides, :encoded_constructor)

    encoded_constructor = encoded_constructor || ""

    tx_params =
      Enum.into(overrides, %{
        data: contract_binary <> encoded_constructor,
        to: nil
      })

    maybe_use_signer(tx_params, opts)
  end

  defp pre_process("0x" <> _ = signed_tx, _overrides, action, _opts)
       when action in @send_transaction_actions do
    {:ok, signed_tx, :eth_send_raw_transaction}
  end

  defp pre_process(tx_data, overrides, action, opts) when action in @send_transaction_actions do
    tx_params = TxData.to_map(tx_data, overrides)

    with :ok <- check_params(tx_params, action) do
      maybe_use_signer(tx_params, opts)
    end
  end

  defp pre_process(tx_data, overrides, :sign_transaction = action, _opts) do
    tx_params = TxData.to_map(tx_data, overrides)

    with :ok <- check_params(tx_params, action) do
      {:ok, tx_params}
    end
  end

  defp pre_process(tx_data, overrides, :estimate_gas = action, _opts) do
    tx_params = TxData.to_map(tx_data, overrides)

    with :ok <- check_params(tx_params, action) do
      {:ok, Transaction.to_rpc_map(tx_params)}
    end
  end

  defp pre_process(_event_filters_module, overrides, :get_logs_for_contract, _opts) do
    log_params =
      overrides
      |> Enum.into(%{})
      |> ensure_hex_value(:fromBlock)
      |> ensure_hex_value(:from_block)
      |> ensure_hex_value(:toBlock)
      |> ensure_hex_value(:to_block)

    {:ok, log_params}
  end

  defp pre_process(event_filter, overrides, :get_logs, _opts) do
    log_params =
      event_filter
      |> EventFilter.to_map(overrides)
      |> ensure_hex_value(:fromBlock)
      |> ensure_hex_value(:from_block)
      |> ensure_hex_value(:toBlock)
      |> ensure_hex_value(:to_block)

    {:ok, log_params}
  end

  defp pre_process([], [], _action, _opts), do: :ok

  defp pre_process(data, [], _action, _opts), do: {:ok, data}

  defp post_process({:ok, resp}, %{selector: %{returns: returns}} = tx_data, :call)
       when returns != [] do
    case Utils.hex_decode(resp) do
      {:ok, ""} ->
        {:error, :invalid_result}

      {:ok, data} ->
        TxData.abi_decode(data, tx_data, :output)

      :error ->
        {:error, :invalid_result}
    end
  end

  defp post_process({:ok, "0x"}, _tx_data, :call) do
    # Handles empty response
    {:ok, nil}
  end

  defp post_process({:ok, resp}, _tx_data, :call) when is_binary(resp) do
    # Handle the case that call was used without a selector (raw call)
    {:ok, resp}
  end

  defp post_process({:ok, tx_hash}, _tx_data, action)
       when valid_result(tx_hash) and action in @send_transaction_actions,
       do: {:ok, tx_hash}

  defp post_process({:ok, tx_hash}, _tx_params, _action = :deploy) when valid_result(tx_hash),
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

  defp post_process({:ok, resp}, event_filters_module, :get_logs_for_contract)
       when is_list(resp) do
    logs =
      Enum.flat_map(resp, fn log ->
        case Event.find_and_decode(log, event_filters_module) do
          {:ok, decoded_log} -> [decoded_log]
          {:error, :not_found} -> []
        end
      end)

    {:ok, logs}
  end

  defp post_process({:ok, resp}, _event_filters_module, :get_logs_for_contract) do
    {:ok, resp}
  end

  defp post_process({:ok, %{"contractAddress" => contract_address}}, _tx_hash, :deployed_address)
       when not is_nil(contract_address),
       do: {:ok, contract_address}

  defp post_process({:ok, nil}, _tx_hash, :deployed_address),
    do: {:error, :transaction_not_found}

  defp post_process({:ok, _}, _tx_hash, :deployed_address),
    do: {:error, :no_contract_address}

  defp post_process({:ok, nil}, _tx_hash, :get_transaction),
    do: {:error, :transaction_not_found}

  defp post_process({:ok, tx_data}, _tx_hash, :get_transaction) do
    Transaction.from_rpc_map(tx_data)
  end

  defp post_process({:ok, nil}, _tx_hash, :get_transaction_receipt),
    do: {:error, :transaction_receipt_not_found}

  defp post_process({:ok, result}, _tx_data, _action),
    do: {:ok, result}

  defp post_process({:error, %{"data" => "0x"} = full_error}, _tx_data, _action),
    do: {:error, full_error}

  defp post_process(
         {:error, %{"data" => "0x" <> error_data} = full_error},
         %{base_module: module},
         _action
       )
       when is_atom(module) do
    error_data = Utils.hex_decode!(error_data)

    errors_module = Module.concat(module, Errors)

    case errors_module.find_and_decode(error_data) do
      {:ok, error} -> {:error, error}
      {:error, :undefined_error} -> {:error, full_error}
      {:error, reason} -> {:error, reason}
    end
  end

  defp post_process({:error, cause}, _tx_data, _action),
    do: {:error, cause}

  defp ensure_hex_value(params, key) do
    case Map.get(params, key) do
      v when is_integer(v) -> %{params | key => Utils.integer_to_hex(v)}
      _ -> params
    end
  end

  defp prepare_requests(requests) do
    Enum.map(requests, fn
      {action, data} -> {action, data, []}
      {action, data, overrides} -> {action, data, overrides}
      action when is_atom(action) -> {action, [], []}
    end)
  end

  defp prepare_batch_requests(requests, opts) do
    requests
    |> Enum.reduce_while([], fn {action, data, overrides}, acc ->
      rpc_action = Map.get(@rpc_actions_map, action, action)

      {sub_opts, overrides} = Keyword.split(overrides, @option_keys)
      opts = Keyword.merge(opts, sub_opts)

      case pre_process(data, overrides, action, opts) do
        :ok ->
          {:cont, [{rpc_action, []} | acc]}

        {:ok, params} ->
          {:cont, [{rpc_action, List.wrap(params)} | acc]}

        {:ok, params, action} when action in [:eth_send_transaction, :eth_send_raw_transaction] ->
          {:cont, [{action, [params]} | acc]}

        {:ok, params, block} ->
          {:cont, [{rpc_action, [params, block]} | acc]}

        {:error, err} ->
          {:halt, {:error, err}}
      end
    end)
    |> case do
      {:error, err} -> {:error, err}
      list -> Enum.reverse(list)
    end
  end

  defp maybe_use_signer(tx_params, opts) do
    case get_signer(opts) do
      {:ok, signer} ->
        use_signer(tx_params, signer, opts)

      {:error, :no_signer} ->
        tx_params = Transaction.to_rpc_map(tx_params)

        {:ok, tx_params, :eth_send_transaction}
    end
  end

  defp get_signer(opts, default \\ default_signer()) do
    case Keyword.get(opts, :signer, default) do
      nil -> {:error, :no_signer}
      signer -> {:ok, signer}
    end
  end

  defp default_signer do
    Application.get_env(:ethers, :default_signer)
  end

  defp default_signer_opts do
    Application.get_env(:ethers, :default_signer_opts, [])
  end

  defp use_signer(tx_params, signer, opts) do
    with {:ok, tx_params} <- Transaction.add_auto_fetchable_fields(tx_params, opts),
         {:ok, tx} <- Transaction.new(tx_params),
         {:ok, signed_tx_hex} <- signer.sign_transaction(tx, build_signer_opts(tx_params, opts)) do
      {:ok, signed_tx_hex, :eth_send_raw_transaction}
    end
  end

  defp build_signer_opts(tx_params, opts) do
    signer_opts = Keyword.get(opts, :signer_opts, default_signer_opts())
    tx_from = Map.get(tx_params, :from)
    signer_from = Keyword.get(signer_opts, :from) || tx_from

    if tx_from do
      if tx_from != signer_from do
        raise ArgumentError, ":signer_opts has a different from address than transaction"
      end

      Keyword.put(signer_opts, :from, tx_from)
    else
      signer_opts
    end
  end

  defp check_to_address(%{to: to_address}, _action) when is_binary(to_address), do: :ok

  defp check_to_address(%{to: nil}, action)
       when action in [:send, :send_transaction, :sign_transaction, :estimate_gas],
       do: :ok

  defp check_to_address(_params, _action), do: {:error, :no_to_address}

  defp check_from_address(%{from: from}, _action) when not is_nil(from), do: :ok

  defp check_from_address(_tx_params, action)
       when action in [:send, :send_transaction, :sign_transaction],
       do: {:error, :no_from_address}

  defp check_from_address(_tx_params, _action), do: :ok

  defp check_params(params, action) do
    with :ok <- check_to_address(params, action) do
      check_from_address(params, action)
    end
  end
end
