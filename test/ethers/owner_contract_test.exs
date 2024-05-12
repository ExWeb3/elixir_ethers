defmodule Ethers.Contract.Test.OwnerContract do
  @moduledoc false
  use Ethers.Contract, abi_file: "tmp/owner_abi.json"
end

defmodule Ethers.OwnerContractTest do
  use ExUnit.Case
  doctest Ethers.Contract

  import Ethers.TestHelpers

  alias Ethers.Contract.Test.OwnerContract

  @from "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266"
  @sample_address "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2"

  test "can deploy and get owner" do
    encoded_constructor = OwnerContract.constructor(@sample_address)

    assert {:ok, tx_hash} =
             Ethers.deploy(OwnerContract, encoded_constructor: encoded_constructor, from: @from)

    wait_for_transaction!(tx_hash)

    assert {:ok, address} = Ethers.deployed_address(tx_hash)

    assert {:ok, @sample_address} = OwnerContract.get_owner() |> Ethers.call(to: address)
  end

  describe "overriding RPC options" do
    test "can override RPC client" do
      encoded_constructor = OwnerContract.constructor(@sample_address)

      assert {:ok, "tx_hash"} =
               Ethers.deploy(OwnerContract,
                 encoded_constructor: encoded_constructor,
                 from: @from,
                 rpc_client: Ethers.TestRPCModule
               )
    end

    test "can override RPC options" do
      encoded_constructor = OwnerContract.constructor(@sample_address)

      assert {:ok, tx_hash} =
               Ethers.deploy(OwnerContract, encoded_constructor: encoded_constructor, from: @from)

      wait_for_transaction!(tx_hash)

      assert {:ok, address} = Ethers.deployed_address(tx_hash)

      assert {:ok, @sample_address} =
               OwnerContract.get_owner()
               |> Ethers.call(
                 to: address,
                 rpc_client: Ethers.TestRPCModule,
                 rpc_opts: [send_back_to_pid: self()]
               )

      assert_receive :eth_call
    end
  end
end
