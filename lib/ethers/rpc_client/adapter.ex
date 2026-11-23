defmodule Ethers.RpcClient.Adapter do
  @moduledoc """
  Behaviour of the JSON-RPC clients Ethers sends its requests with.

  Ethers talks to a node through an RPC client module. The default one sends requests over HTTP
  with Ethereumex. Implement this behaviour to use another transport, to route requests between
  several endpoints, or to add retries, rate limiting or instrumentation.

  ## Using an adapter

  Set it as the default client:

  ```elixir
  config :ethers, rpc_client: MyApp.RpcClient
  ```

  Or choose it for a single request with the `:rpc_client` option:

  ```elixir
  Ethers.call(tx_data, rpc_client: MyApp.RpcClient, rpc_opts: [url: "https://..."])
  ```

  ## Implementing an adapter

  Each callback sends the JSON-RPC method it is named after, `eth_get_balance/3` for
  `eth_getBalance`.

  ```elixir
  defmodule MyApp.RpcClient do
    @behaviour Ethers.RpcClient.Adapter

    @impl true
    def eth_block_number(opts), do: request("eth_blockNumber", [], opts)

    @impl true
    def eth_get_balance(account, block, opts) do
      request("eth_getBalance", [account, block], opts)
    end

    # ... the other callbacks

    defp request(method, params, opts) do
      # Send the request, then return {:ok, result} or {:error, reason}
    end
  end
  ```

  - **Arguments** are the parameters of the method, in order and already encoded for JSON-RPC:
    quantities and data are `0x` prefixed hex strings, blocks are a hex quantity or a tag such as
    `"latest"`, and transactions, filters and state overrides are maps.
  - **The last argument** is the `:rpc_opts` keyword list of the request (`[]` if not given). It is
    passed as is, so an adapter defines its own options.
  - **The return value** is `{:ok, result}` with the `result` member of the JSON-RPC response,
    decoded from JSON and otherwise untouched, or `{:error, reason}`. Return the JSON-RPC `error`
    member as `reason` when the node responds with one. Ethers decodes the custom errors of a
    contract from its `"data"` member.

  ## Optional callbacks

  An adapter may leave out the callbacks below. The functions that need them then return an error:

  | Callback | Without it |
  | --- | --- |
  | `c:eth_call/4`, `c:eth_estimate_gas/4` | `:state_overrides` returns `{:error, :state_overrides_not_supported}` |
  | `c:eth_config/1` | `Ethers.config/1` returns `{:error, :not_supported}` |
  | `c:eth_create_access_list/3` | `Ethers.create_access_list/2` returns `{:error, :not_supported}` |
  | `c:eth_fee_history/4` | `Ethers.fee_history/4` returns `{:error, :not_supported}`, and missing transaction fees are filled in from `eth_gasPrice` and `eth_maxPriorityFeePerGas` |
  | `c:eth_get_code/3` | `Ethers.get_code/2` returns `{:error, :not_supported}` |
  """

  @typedoc """
  A failed request.

  The reason is the `error` member of the JSON-RPC response (a map with `"code"`, `"message"` and
  optionally `"data"`), or a description of a failure of the client itself.
  """
  @type error :: {:error, map() | binary() | atom()}

  @doc """
  Sends several requests as one JSON-RPC batch.

  Each request is a `{method, params}` tuple. `method` is the name of a callback of this
  behaviour, or of any other method given to `Ethers.batch/2` (such as `:net_version`), and
  `params` are its arguments without the options.

  Returns the `{:ok, result}` or `{:error, reason}` of every request, in the order of the
  requests.
  """
  @callback batch_request([{method :: atom(), params :: [term()]}], keyword()) ::
              {:ok, [{:ok, term()} | {:error, term()}]} | error()

  @doc "Sends `eth_blockNumber`."
  @callback eth_block_number(keyword()) :: {:ok, binary()} | error()

  @doc "Sends `eth_call`."
  @callback eth_call(map(), binary(), keyword()) :: {:ok, binary()} | error()

  @doc "Sends `eth_call` with state overrides."
  @callback eth_call(map(), binary(), state_overrides :: map(), keyword()) ::
              {:ok, binary()} | error()

  @doc "Sends `eth_chainId`."
  @callback eth_chain_id(keyword()) :: {:ok, binary()} | error()

  @doc "Sends `eth_config`."
  @callback eth_config(keyword()) :: {:ok, map()} | error()

  @doc "Sends `eth_createAccessList`."
  @callback eth_create_access_list(map(), binary(), keyword()) :: {:ok, map()} | error()

  @doc "Sends `eth_estimateGas`."
  @callback eth_estimate_gas(map(), keyword()) :: {:ok, binary()} | error()

  @doc "Sends `eth_estimateGas` with state overrides."
  @callback eth_estimate_gas(map(), binary(), state_overrides :: map(), keyword()) ::
              {:ok, binary()} | error()

  @doc "Sends `eth_feeHistory`."
  @callback eth_fee_history(
              block_count :: binary(),
              newest_block :: binary(),
              reward_percentiles :: [number()],
              keyword()
            ) :: {:ok, map()} | error()

  @doc "Sends `eth_gasPrice`."
  @callback eth_gas_price(keyword()) :: {:ok, binary()} | error()

  @doc "Sends `eth_getBalance`."
  @callback eth_get_balance(binary(), binary(), keyword()) :: {:ok, binary()} | error()

  @doc "Sends `eth_getCode`."
  @callback eth_get_code(binary(), binary(), keyword()) :: {:ok, binary()} | error()

  @doc """
  Sends `eth_getBlockByNumber`.

  The result is `nil` if the block does not exist.
  """
  @callback eth_get_block_by_number(binary() | non_neg_integer(), boolean(), keyword()) ::
              {:ok, map() | nil} | error()

  @doc """
  Sends `eth_getTransactionByHash`.

  The result is `nil` if the transaction is not found.
  """
  @callback eth_get_transaction_by_hash(binary(), keyword()) :: {:ok, map() | nil} | error()

  @doc "Sends `eth_getTransactionCount`."
  @callback eth_get_transaction_count(binary(), binary(), keyword()) :: {:ok, binary()} | error()

  @doc """
  Sends `eth_getTransactionReceipt`.

  The result is `nil` if the transaction is not found or not mined yet.
  """
  @callback eth_get_transaction_receipt(binary(), keyword()) :: {:ok, map() | nil} | error()

  @doc "Sends `eth_maxPriorityFeePerGas`."
  @callback eth_max_priority_fee_per_gas(keyword()) :: {:ok, binary()} | error()

  @doc "Sends `eth_blobBaseFee`."
  @callback eth_blob_base_fee(keyword()) :: {:ok, binary()} | error()

  @doc "Sends `eth_getLogs`."
  @callback eth_get_logs(map(), keyword()) :: {:ok, [binary()] | [map()]} | error()

  @doc "Sends `eth_sendTransaction`."
  @callback eth_send_transaction(map(), keyword()) :: {:ok, binary()} | error()

  @doc "Sends `eth_sendRawTransaction`."
  @callback eth_send_raw_transaction(binary(), keyword()) :: {:ok, binary()} | error()

  # New callbacks are optional to keep custom RPC client adapters backwards compatible.
  # Ethers checks their availability with `function_exported?/3` before use.
  @optional_callbacks eth_call: 4,
                      eth_config: 1,
                      eth_create_access_list: 3,
                      eth_estimate_gas: 4,
                      eth_fee_history: 4,
                      eth_get_code: 3
end
