defmodule Ethers.RpcClient.Adapter do
  @moduledoc false

  @type error :: {:error, map() | binary() | atom()}

  @callback batch_request([{atom(), list(boolean() | binary())}], keyword()) ::
              {:ok, [any()]} | error

  @callback eth_block_number(keyword()) :: {:ok, binary()} | error()

  @callback eth_call(map(), binary(), keyword()) :: {:ok, binary()} | error()

  @callback eth_call(map(), binary(), state_overrides :: map(), keyword()) ::
              {:ok, binary()} | error()

  @callback eth_chain_id(keyword()) :: {:ok, binary()} | error()

  @callback eth_create_access_list(map(), binary(), keyword()) :: {:ok, map()} | error()

  @callback eth_estimate_gas(map(), keyword()) :: {:ok, binary()} | error()

  @callback eth_estimate_gas(map(), binary(), state_overrides :: map(), keyword()) ::
              {:ok, binary()} | error()

  @callback eth_fee_history(
              block_count :: binary(),
              newest_block :: binary(),
              reward_percentiles :: [number()],
              keyword()
            ) :: {:ok, map()} | error()

  @callback eth_gas_price(keyword()) :: {:ok, binary()} | error()

  @callback eth_get_balance(binary(), binary(), keyword()) :: {:ok, binary()} | error()

  @callback eth_get_block_by_number(binary() | non_neg_integer(), boolean(), keyword()) ::
              {:ok, map()} | error()

  @callback eth_get_transaction_by_hash(binary(), keyword()) :: {:ok, map()} | error()

  @callback eth_get_transaction_count(binary(), binary(), keyword()) :: {:ok, binary()} | error()

  @callback eth_get_transaction_receipt(binary(), keyword()) :: {:ok, map()} | error()

  @callback eth_max_priority_fee_per_gas(keyword()) :: {:ok, binary()} | error()

  @callback eth_blob_base_fee(keyword()) :: {:ok, binary()} | error()

  @callback eth_get_logs(map(), keyword()) :: {:ok, [binary()] | [map()]} | error()

  @callback eth_send_transaction(map(), keyword()) :: {:ok, binary()} | error()

  @callback eth_send_raw_transaction(binary(), keyword()) :: {:ok, binary()} | error()

  # New callbacks are optional to keep custom RPC client adapters backwards compatible.
  # Ethers checks their availability with `function_exported?/3` before use.
  @optional_callbacks eth_call: 4,
                      eth_create_access_list: 3,
                      eth_estimate_gas: 4,
                      eth_fee_history: 4
end
