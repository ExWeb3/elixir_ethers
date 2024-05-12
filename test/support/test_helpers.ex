defmodule Ethers.TestHelpers do
  @moduledoc false

  @max_tries 5

  def wait_for_transaction!(tx_hash, opts \\ [], try_count \\ 0)

  def wait_for_transaction!(_tx_hash, _opts, @max_tries) do
    raise "Transaction was not found after #{@max_tries} tries"
  end

  def wait_for_transaction!(tx_hash, opts, try_count) do
    case Ethers.get_transaction_receipt(tx_hash, opts) do
      {:ok, _} ->
        :ok

      {:error, _} ->
        Process.sleep(try_count * 50)

        wait_for_transaction!(tx_hash, opts, try_count + 1)
    end
  end

  def deploy(bin_or_module, opts \\ []) do
    {:ok, tx_hash} = Ethers.deploy(bin_or_module, opts)
    wait_for_transaction!(tx_hash, opts)
    {:ok, address} = Ethers.deployed_address(tx_hash, opts)
    address
  end
end
