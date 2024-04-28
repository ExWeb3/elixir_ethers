defmodule Ethers.TestDeployer do
  @moduledoc false

  import ExUnit.Assertions

  def deploy(bin_or_mod, opts) do
    assert {:ok, tx} = Ethers.deploy(bin_or_mod, opts)
    Process.sleep(50)
    assert {:ok, contract_address} = Ethers.deployed_address(tx)
    contract_address
  end
end
