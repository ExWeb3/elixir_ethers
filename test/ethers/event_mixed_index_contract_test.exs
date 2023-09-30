defmodule Ethers.Contract.Test.EventMixedIndexContract do
  @moduledoc false
  use Ethers.Contract, abi_file: "tmp/event_mixed_index_abi.json"
end

defmodule Ethers.EventMixedIndexContractTest do
  use ExUnit.Case

  alias Ethers.Contract.Test.EventMixedIndexContract

  @test_address "0x90f8bf6a479f320ead074411a4b0e7944ea8c9c1"

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
                 returns: [{:uint, 256}, :bool]
               },
               topics: [
                 "0x0f1459b71050cedb12633644ebaa16569e1bb49626ab8a0f4c7d1cf0d574abe7",
                 "0x00000000000000000000000090f8bf6a479f320ead074411a4b0e7944ea8c9c1",
                 "0x00000000000000000000000090f8bf6a479f320ead074411a4b0e7944ea8c9c1"
               ]
             } == EventMixedIndexContract.EventFilters.transfer(@test_address, @test_address)
    end
  end
end
