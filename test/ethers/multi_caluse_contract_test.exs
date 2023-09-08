defmodule Ethers.Contract.Test.MultiClauseContract do
  @moduledoc false
  use Ethers.Contract, abi_file: "tmp/multi_clause_abi.json"
end

defmodule Ethers.MultiClauseContractTest do
  use ExUnit.Case

  alias Ethers.Contract.Test.MultiClauseContract

  @from "0x90f8bf6a479f320ead074411a4b0e7944ea8c9c1"

  describe "next function" do
    test "can override RPC client" do
      init_params = MultiClauseContract.constructor()
      assert {:ok, tx_hash} = Ethers.deploy(MultiClauseContract, init_params, %{from: @from})
      assert {:ok, address} = Ethers.deployed_address(tx_hash)

      assert {:ok, [0]} = MultiClauseContract.next() |> Ethers.call(to: address)
      assert {:ok, [6]} = MultiClauseContract.next(5) |> Ethers.call(to: address)
      assert {:ok, [7]} = MultiClauseContract.next(6) |> Ethers.call(to: address)
    end
  end
end
