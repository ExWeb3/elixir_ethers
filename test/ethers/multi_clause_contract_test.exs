defmodule Ethers.Contract.Test.MultiClauseContract do
  @moduledoc false
  use Ethers.Contract, abi_file: "tmp/multi_clause_abi.json"
end

defmodule Ethers.MultiClauseContractTest do
  use ExUnit.Case

  alias Ethers.Contract.Test.MultiClauseContract

  @from "0x90f8bf6a479f320ead074411a4b0e7944ea8c9c1"

  setup :deploy_multi_clause_contract

  describe "next function" do
    test "will raise on ambiguous arguments" do
      assert_raise ArgumentError,
                   "Ambiguous parameters\n\n## Arguments\n[1]\n\n## Conflicting function signatures\nsay(uint128 n)\nsay(uint8 n)\nsay(int256 n)\nsay(uint256 n)\n",
                   fn ->
                     MultiClauseContract.say(1)
                   end
    end

    test "will raise on non matching arguments" do
      assert_raise ArgumentError,
                   "No function selector matches current arguments!\n\n## Arguments\n[{:typed, {:uint, 64}, 1}]\n\n## Conflicting function signatures\nsay(address n)\nsay(uint128 n)\nsay(uint8 n)\nsay(int256 n)\nsay(uint256 n)\nsay(string n)\n",
                   fn ->
                     MultiClauseContract.say({:typed, {:uint, 64}, 1})
                   end
    end

    test "will work with typed arguments", %{address: address} do
      assert ["uint256"] ==
               MultiClauseContract.say({:typed, {:uint, 256}, 101}) |> Ethers.call!(to: address)

      assert ["int256"] ==
               MultiClauseContract.say({:typed, {:int, 256}, 101}) |> Ethers.call!(to: address)

      assert ["int256"] ==
               MultiClauseContract.say({:typed, {:int, 256}, 101}) |> Ethers.call!(to: address)
    end
  end

  describe "smart function" do
    test "can deduce type based on properties", %{address: address} do
      assert ["uint8"] == MultiClauseContract.smart(255) |> Ethers.call!(to: address)
      assert ["int8"] == MultiClauseContract.smart(-1) |> Ethers.call!(to: address)
    end
  end

  defp deploy_multi_clause_contract(_ctx) do
    init_params = MultiClauseContract.constructor()
    assert {:ok, tx_hash} = Ethers.deploy(MultiClauseContract, init_params, %{from: @from})
    assert {:ok, address} = Ethers.deployed_address(tx_hash)

    [address: address]
  end
end
