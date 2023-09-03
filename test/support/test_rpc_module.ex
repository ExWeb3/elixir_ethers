defmodule Ethers.TestRPCModule do
  @moduledoc false

  import Ethers.Utils

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

  def eth_block_number(opts) do
    {:ok, opts[:block]}
  end

  def eth_get_block_by_number(number, _include_all?, opts) do
    timestamp =
      number
      |> hex_to_integer!()
      |> Kernel.+(opts[:timestamp])
      |> integer_to_hex()

    {:ok, %{"timestamp" => timestamp}}
  end
end
