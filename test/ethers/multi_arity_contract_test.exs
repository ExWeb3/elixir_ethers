defmodule Ethers.Contract.Test.MultiArityContract do
  @moduledoc false
  use Ethers.Contract, abi_file: "tmp/multi_arity_abi.json"
end

defmodule Ethers.MultiArityContractTest do
  use ExUnit.Case

  alias Ethers.Contract.Test.MultiArityContract

  @from "0x90f8bf6a479f320ead074411a4b0e7944ea8c9c1"

  describe "next function" do
    test "can override RPC client" do
      init_params = MultiArityContract.constructor()
      assert {:ok, tx_hash} = Ethers.deploy(MultiArityContract, init_params, %{from: @from})
      assert {:ok, address} = Ethers.deployed_address(tx_hash)

      assert {:ok, [0]} = MultiArityContract.next() |> Ethers.call(to: address)
      assert {:ok, [6]} = MultiArityContract.next(5) |> Ethers.call(to: address)
      assert {:ok, [7]} = MultiArityContract.next(6) |> Ethers.call(to: address)
    end
  end
end
