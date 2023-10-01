defmodule Ethers.Contract.Test.EventMixedIndexContract do
  @moduledoc false
  use Ethers.Contract, abi_file: "tmp/event_mixed_index_abi.json"
end

defmodule Ethers.EventMixedIndexContractTest do
  use ExUnit.Case

  alias Ethers.Contract.Test.EventMixedIndexContract

  @from "0x90f8bf6a479f320ead074411a4b0e7944ea8c9c1"

  describe "event filters" do
    test "works with mixed indexed events" do
      assert %{
               selector: %ABI.FunctionSelector{
                 function: "Transfer",
                 method_id: <<15, 20, 89, 183>>,
                 type: :event,
                 inputs_indexed: [false, true, false, true],
                 state_mutability: nil,
                 input_names: ["amount", "sender", "isFinal", "receiver"],
                 types: [{:uint, 256}, :address, :bool, :address],
                 returns: []
               },
               topics: [
                 "0x0f1459b71050cedb12633644ebaa16569e1bb49626ab8a0f4c7d1cf0d574abe7",
                 "0x00000000000000000000000090f8bf6a479f320ead074411a4b0e7944ea8c9c1",
                 "0x00000000000000000000000090f8bf6a479f320ead074411a4b0e7944ea8c9c1"
               ]
             } == EventMixedIndexContract.EventFilters.transfer(@from, @from)
    end

    test "can filter and show the correct events" do
      init_params = EventMixedIndexContract.constructor()
      assert {:ok, tx_hash} = Ethers.deploy(EventMixedIndexContract, init_params, %{from: @from})
      assert {:ok, address} = Ethers.deployed_address(tx_hash)

      EventMixedIndexContract.transfer(100, @from, true, @from)
      |> Ethers.send!(to: address, from: @from)

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
                   "0x00000000000000000000000090f8bf6a479f320ead074411a4b0e7944ea8c9c1",
                   "0x00000000000000000000000090f8bf6a479f320ead074411a4b0e7944ea8c9c1"
                 ],
                 data_raw:
                   "0x00000000000000000000000000000000000000000000000000000000000000640000000000000000000000000000000000000000000000000000000000000001"
               }
             ] = Ethers.get_logs!(filter)
    end
  end
end
