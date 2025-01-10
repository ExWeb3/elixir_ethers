defmodule Ethers.RpcClient.Adapter do
  @moduledoc false

  @type error :: {:error, map() | binary() | atom()}

  @callback batch_request([{atom(), list(boolean() | binary())}], keyword()) ::
              {:ok, [any()]} | error

  @callback eth_block_number(keyword()) :: {:ok, binary()} | error()

  @callback eth_call(map(), binary(), keyword()) :: {:ok, binary()} | error()

  @callback eth_chain_id(keyword()) :: {:ok, binary()} | error()

  @callback eth_estimate_gas(map(), keyword()) :: {:ok, binary()} | error()

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
end
