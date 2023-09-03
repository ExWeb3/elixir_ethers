defmodule Ethers.EventTest do
  use ExUnit.Case
  alias Ethers.Event
  doctest Event

  test "decode log with no data returns empty list" do
    selector = %ABI.FunctionSelector{
      function: "Approval",
      method_id: <<140, 91, 225, 229>>,
      type: :event,
      inputs_indexed: [true, true, false],
      state_mutability: nil,
      input_names: ["owner", "spender", "value"],
      types: [:address, :address, {:uint, 256}],
      returns: [uint: 256]
    }

    assert %Ethers.Event{data: []} =
             Event.decode(
               %{
                 "address" => "0xaa107ccfe230a29c345fd97bc6eb9bd2fccd0750",
                 "blockHash" =>
                   "0xe8885761ec559c5e267c48f44b4b12e4169f7d3a116f5e8f43314147722f0d83",
                 "blockNumber" => "0x1138b39",
                 "data" => "0x",
                 "logIndex" => "0x1a1",
                 "removed" => false,
                 "topics" => [
                   "0x8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b925",
                   "0x00000000000000000000000023c5d7a16cf2e14a00f1c81be9443259f3cbc4ce",
                   "0x0000000000000000000000000000000000000000000000000000000000000000",
                   "0x0000000000000000000000000000000000000000000000000000000000000ef7"
                 ],
                 "transactionHash" =>
                   "0xf6e06e4f3fbd67088e8278843e55862957537760c63bae7b682a0e39da75b45d",
                 "transactionIndex" => "0x83"
               },
               selector
             )
  end
end
