defmodule Ethers.Contract.Test.MultiArityContract do
  @moduledoc false
  use Ethers.Contract, abi_file: "tmp/multi_arity_abi.json"
end

defmodule Ethers.MultiArityContractTest do
  use ExUnit.Case

  import Ethers.TestHelpers

  alias Ethers.Contract.Test.MultiArityContract

  @from "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266"

  describe "next function" do
    test "can override RPC client" do
      encoded_constructor = MultiArityContract.constructor()

      assert {:ok, tx_hash} =
               Ethers.deploy(MultiArityContract,
                 encoded_constructor: encoded_constructor,
                 from: @from
               )

      wait_for_transaction!(tx_hash)

      assert {:ok, address} = Ethers.deployed_address(tx_hash)

      assert {:ok, 0} = MultiArityContract.next() |> Ethers.call(to: address)
      assert {:ok, 6} = MultiArityContract.next(5) |> Ethers.call(to: address)
      assert {:ok, 7} = MultiArityContract.next(6) |> Ethers.call(to: address)
    end
  end
end
