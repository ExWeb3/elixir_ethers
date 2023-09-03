defmodule Ethers.TestRPCModule do
  @moduledoc false

  def eth_estimate_gas(_params, _opts) do
    {:ok, "0x100"}
  end

  def eth_send_transaction(_params, _opts) do
    {:ok, "tx_hash"}
  end

  def eth_call(params, block, opts) do
    if pid = opts[:send_back_to_pid] do
      send(pid, :eth_call)
    end

    Ethereumex.HttpClient.eth_call(params, block, opts)
  end
end
