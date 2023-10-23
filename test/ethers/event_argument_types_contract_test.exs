defmodule Ethers.Contract.Test.EventArgumentTypesContract do
  @moduledoc false
  use Ethers.Contract, abi_file: "tmp/event_argument_types_abi.json"
end

defmodule Ethers.EventArgumentTypesContractTest do
  use ExUnit.Case

  alias Ethers.Contract.Test.EventArgumentTypesContract

  describe "event filters" do
    test "works with strings" do
      filter =
        EventArgumentTypesContract.EventFilters.test_event(Ethers.Types.typed(:string, "ethers"))

      assert %Ethers.EventFilter{
               selector: %ABI.FunctionSelector{
                 function: "TestEvent",
                 input_names: ["numbers", "has_won"],
                 inputs_indexed: [true, false],
                 method_id: "\x05\xFA4\xD0",
                 returns: [],
                 state_mutability: nil,
                 type: :event,
                 types: [:string, :bool]
               },
               topics: [
                 "0x05fa34d0d20b7c225e7b176f34bcf7538f55be08ce7caf15cc5789c3fc32646c",
                 "0x86192adb5c990d8714151ec0eb2d7767d35c867add4a59bc860d0ef09cd76ee7"
               ],
               default_address: nil
             } == filter

      assert "#Ethers.EventFilter<event TestEvent(string indexed numbers (hashed) \"0x86192adb5c990d8714151ec0eb2d7767d35c867add4a59bc860d0ef09cd76ee7\", bool has_won)>" ==
               inspect(filter)
    end

    test "works with bytes" do
      filter =
        EventArgumentTypesContract.EventFilters.test_event(
          Ethers.Types.typed(:bytes, <<1, 2, 3>>)
        )

      assert %Ethers.EventFilter{
               selector: %ABI.FunctionSelector{
                 function: "TestEvent",
                 input_names: ["numbers", "has_won"],
                 inputs_indexed: [true, false],
                 method_id: "\x9Bm\x1E\xFF",
                 returns: [],
                 state_mutability: nil,
                 type: :event,
                 types: [:bytes, :bool]
               },
               topics: [
                 "0x9b6d1eff0add9c1c52995c5d2e7b50ba11dc2535256cb88d7ed507bff2794a42",
                 "0xf1885eda54b7a053318cd41e2093220dab15d65381b1157a3633a83bfd5c9239"
               ],
               default_address: nil
             } == filter

      assert "#Ethers.EventFilter<event TestEvent(bytes indexed numbers (hashed) \"0xf1885eda54b7a053318cd41e2093220dab15d65381b1157a3633a83bfd5c9239\", bool has_won)>" ==
               inspect(filter)
    end

    test "works with unbounded arrays" do
      filter = EventArgumentTypesContract.EventFilters.test_event([1, 2, 3, 4, 5])

      assert %Ethers.EventFilter{
               selector: %ABI.FunctionSelector{
                 function: "TestEvent",
                 input_names: ["numbers", "has_won"],
                 inputs_indexed: [true, false],
                 method_id: "E(\x99\t",
                 returns: [],
                 state_mutability: nil,
                 type: :event,
                 types: [{:array, {:uint, 256}}, :bool]
               },
               topics: [
                 "0x452899094966d30dee615ca51e9f6f0f5ef486fee956f3bc3d8d38381a830ae7",
                 "0x5917e5a395fb9b454434de59651d36822a9e29c5ec57474df3e67937b969460c"
               ],
               default_address: nil
             } == filter

      assert "#Ethers.EventFilter<event TestEvent(uint256[] indexed numbers (hashed) \"0x5917e5a395fb9b454434de59651d36822a9e29c5ec57474df3e67937b969460c\", bool has_won)>" ==
               inspect(filter)
    end

    test "works with bounded arrays" do
      filter =
        EventArgumentTypesContract.EventFilters.test_event(
          Ethers.Types.typed({:array, {:uint, 256}, 3}, [1, 2, 3])
        )

      assert %Ethers.EventFilter{
               selector: %ABI.FunctionSelector{
                 function: "TestEvent",
                 input_names: ["numbers", "has_won"],
                 inputs_indexed: [true, false],
                 method_id: "\xDAF\xD1<",
                 returns: [],
                 state_mutability: nil,
                 type: :event,
                 types: [{:array, {:uint, 256}, 3}, :bool]
               },
               topics: [
                 "0xda46d13c877fe85be32813ad8ae8e248bdb8cfc433c47cb648bf18229e3e79b5",
                 "0x6e0c627900b24bd432fe7b1f713f1b0744091a646a9fe4a65a18dfed21f2949c"
               ],
               default_address: nil
             } == filter

      assert "#Ethers.EventFilter<event TestEvent(uint256[3] indexed numbers (hashed) \"0x6e0c627900b24bd432fe7b1f713f1b0744091a646a9fe4a65a18dfed21f2949c\", bool has_won)>" ==
               inspect(filter)
    end

    test "works with tuples (structs)" do
      filter = EventArgumentTypesContract.EventFilters.test_event({1, 2, 3})

      assert %Ethers.EventFilter{
               selector: %ABI.FunctionSelector{
                 function: "TestEvent",
                 input_names: ["numbers", "has_won"],
                 inputs_indexed: [true, false],
                 method_id: "Xnc\xBB",
                 returns: [],
                 state_mutability: nil,
                 type: :event,
                 types: [{:tuple, [{:uint, 256}, {:uint, 256}, {:uint, 256}]}, :bool]
               },
               topics: [
                 "0x586e63bbc89d8901dcdf36aacc9068837356d52ccafae5ecf041e3b03fc373c1",
                 "0x6e0c627900b24bd432fe7b1f713f1b0744091a646a9fe4a65a18dfed21f2949c"
               ],
               default_address: nil
             } == filter

      assert "#Ethers.EventFilter<event TestEvent((uint256,uint256,uint256) indexed numbers (hashed) \"0x6e0c627900b24bd432fe7b1f713f1b0744091a646a9fe4a65a18dfed21f2949c\", bool has_won)>" ==
               inspect(filter)
    end
  end
end
