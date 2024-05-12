defmodule Ethers.Contract.Test.EventMixedIndexContract do
  @moduledoc false
  use Ethers.Contract, abi_file: "tmp/event_mixed_index_abi.json"
end

defmodule Ethers.EventMixedIndexContractTest do
  use ExUnit.Case

  import Ethers.TestHelpers

  alias Ethers.Contract.Test.EventMixedIndexContract

  @from "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266"

  describe "event filters" do
    test "works with mixed indexed events" do
      assert %Ethers.EventFilter{
               selector: %ABI.FunctionSelector{
                 function: "Transfer",
                 method_id:
                   Ethers.Utils.hex_decode!(
                     "0x0f1459b71050cedb12633644ebaa16569e1bb49626ab8a0f4c7d1cf0d574abe7"
                   ),
                 type: :event,
                 inputs_indexed: [false, true, false, true],
                 state_mutability: nil,
                 input_names: ["amount", "sender", "isFinal", "receiver"],
                 types: [{:uint, 256}, :address, :bool, :address],
                 returns: []
               },
               topics: [
                 "0x0f1459b71050cedb12633644ebaa16569e1bb49626ab8a0f4c7d1cf0d574abe7",
                 "0x000000000000000000000000f39fd6e51aad88f6f4ce6ab8827279cfffb92266",
                 "0x000000000000000000000000f39fd6e51aad88f6f4ce6ab8827279cfffb92266"
               ],
               default_address: nil
             } == EventMixedIndexContract.EventFilters.transfer(@from, @from)
    end

    test "can filter and show the correct events" do
      encoded_constructor = EventMixedIndexContract.constructor()

      assert {:ok, tx_hash} =
               Ethers.deploy(EventMixedIndexContract,
                 encoded_constructor: encoded_constructor,
                 from: @from
               )

      wait_for_transaction!(tx_hash)

      assert {:ok, address} = Ethers.deployed_address(tx_hash)

      EventMixedIndexContract.transfer(100, @from, true, @from)
      |> Ethers.send!(to: address, from: @from)
      |> wait_for_transaction!()

      filter = EventMixedIndexContract.EventFilters.transfer(@from, @from)

      assert [
               %Ethers.Event{
                 address: ^address,
                 topics: ["Transfer(uint256,address,bool,address)", @from, @from],
                 data: [100, true],
                 removed: false,
                 log_index: 0,
                 transaction_index: 0,
                 topics_raw: [
                   "0x0f1459b71050cedb12633644ebaa16569e1bb49626ab8a0f4c7d1cf0d574abe7",
                   "0x000000000000000000000000f39fd6e51aad88f6f4ce6ab8827279cfffb92266",
                   "0x000000000000000000000000f39fd6e51aad88f6f4ce6ab8827279cfffb92266"
                 ],
                 data_raw:
                   "0x00000000000000000000000000000000000000000000000000000000000000640000000000000000000000000000000000000000000000000000000000000001"
               }
             ] = Ethers.get_logs!(filter)
    end

    test "inspect returns correct value" do
      assert ~s'#Ethers.EventFilter<event Transfer(uint256 amount, address indexed sender "0x90f8bf6a479f320ead074411a4b0e7944ea80000", bool isFinal, address indexed receiver "0x90f8bf6a479f320ead074411a4b0e7944ea80001")>' ==
               inspect(
                 EventMixedIndexContract.EventFilters.transfer(
                   "0x90f8bf6a479f320ead074411a4b0e7944ea80000",
                   "0x90f8bf6a479f320ead074411a4b0e7944ea80001"
                 )
               )

      assert ~s'#Ethers.EventFilter<event Transfer(uint256 amount, address indexed sender any, bool isFinal, address indexed receiver "0x90f8bf6a479f320ead074411a4b0e7944ea80001")>' ==
               inspect(
                 EventMixedIndexContract.EventFilters.transfer(
                   nil,
                   "0x90f8bf6a479f320ead074411a4b0e7944ea80001"
                 )
               )
    end
  end
end
