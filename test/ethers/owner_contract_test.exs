defmodule Ethers.Contract.Test.OwnerContract do
  @moduledoc false
  use Ethers.Contract, abi_file: "tmp/owner_abi.json"
end

defmodule Ethers.OwnerContractTest do
  use ExUnit.Case
  doctest Ethers.Contract

  alias Ethers.Contract.Test.OwnerContract

  @from "0x90f8bf6a479f320ead074411a4b0e7944ea8c9c1"
  @sample_address "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2"

  test "can deploy and get owner" do
    init_params = OwnerContract.constructor(@sample_address)
    assert {:ok, tx_hash} = Ethers.deploy(OwnerContract, init_params, %{from: @from})
    assert {:ok, address} = Ethers.deployed_address(tx_hash)

    assert {:ok, [@sample_address]} = OwnerContract.get_owner(to: address)
  end
end
