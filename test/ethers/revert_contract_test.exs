defmodule Ethers.Contract.Test.RevertContract do
  @moduledoc false
  use Ethers.Contract, abi_file: "tmp/revert_abi.json"
end

defmodule Ethers.RevertContractTest do
  use ExUnit.Case

  alias Ethers.Contract.Test.RevertContract

  @from "0x90f8bf6a479f320ead074411a4b0e7944ea8c9c1"

  describe "next function" do
    test "can override RPC client" do
      init_params = RevertContract.constructor()
      assert {:ok, tx_hash} = Ethers.deploy(RevertContract, init_params, %{from: @from})
      assert {:ok, address} = Ethers.deployed_address(tx_hash)

      assert {:ok, true} = RevertContract.get(true) |> Ethers.call(to: address, from: @from)

      assert {:error, %{"message" => message}} =
               RevertContract.get(false) |> Ethers.call(to: address, from: @from)

      assert message =~ "success must be true"

      assert_raise Ethers.ExecutionError,
                   "VM Exception while processing transaction: revert success must be true",
                   fn ->
                     RevertContract.get(false) |> Ethers.call!(to: address, from: @from)
                   end
    end
  end
end
