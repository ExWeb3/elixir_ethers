defmodule Ethers.Contract.Test.MultiClauseContract do
  @moduledoc false
  use Ethers.Contract, abi_file: "tmp/multi_clause_abi.json"
end

defmodule Ethers.MultiClauseContractTest do
  use ExUnit.Case

  import Ethers.Types, only: [typed: 2]
  import Ethers.TestHelpers

  alias Ethers.Contract.Test.MultiClauseContract

  @from "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266"

  setup_all :deploy_multi_clause_contract

  describe "next function" do
    test "will raise on ambiguous arguments" do
      assert_raise ArgumentError,
                   "Ambiguous parameters\n\n## Arguments\n[1]\n\n## Possible signatures\nsay(uint128 n)\nsay(uint8 n)\nsay(int256 n)\nsay(uint256 n)\n",
                   fn ->
                     MultiClauseContract.say(1)
                   end
    end

    test "will raise on non matching arguments" do
      assert_raise ArgumentError,
                   "No function selector matches current arguments!\n\n## Arguments\n[{:typed, {:uint, 64}, 1}]\n\n## Available signatures\nsay(address n)\nsay(uint128 n)\nsay(uint8 n)\nsay(int256 n)\nsay(uint256 n)\nsay(string n)\n",
                   fn ->
                     MultiClauseContract.say(typed({:uint, 64}, 1))
                   end
    end

    test "will work with typed arguments", %{address: address} do
      assert "uint256" ==
               MultiClauseContract.say(typed({:uint, 256}, 101)) |> Ethers.call!(to: address)

      assert "int256" ==
               MultiClauseContract.say(typed({:int, 256}, 101)) |> Ethers.call!(to: address)

      assert "int256" ==
               MultiClauseContract.say(typed({:int, 256}, 101)) |> Ethers.call!(to: address)
    end
  end

  describe "smart function" do
    test "can deduce type based on properties", %{address: address} do
      assert "uint8" == MultiClauseContract.smart(255) |> Ethers.call!(to: address)
      assert "int8" == MultiClauseContract.smart(-1) |> Ethers.call!(to: address)
    end
  end

  describe "multi clause events" do
    test "listens on the right event", %{address: address} do
      MultiClauseContract.emit_event(typed({:uint, 256}, 10))
      |> Ethers.send_transaction!(to: address, from: @from)
      |> wait_for_transaction!()

      uint_filter = MultiClauseContract.EventFilters.multi_event(typed({:uint, 256}, 10))

      assert {:ok, [%Ethers.Event{address: ^address, topics: ["MultiEvent(uint256)", 10]}]} =
               Ethers.get_logs(uint_filter, address: address)

      MultiClauseContract.emit_event(typed({:int, 256}, -20))
      |> Ethers.send_transaction!(to: address, from: @from)
      |> wait_for_transaction!()

      int_filter = MultiClauseContract.EventFilters.multi_event(typed({:int, 256}, -20))

      assert {:ok, [%Ethers.Event{address: ^address, topics: ["MultiEvent(int256)", -20]}]} =
               Ethers.get_logs(int_filter, address: address)

      MultiClauseContract.emit_event("Hello")
      |> Ethers.send_transaction!(to: address, from: @from)
      |> wait_for_transaction!()

      string_filter = MultiClauseContract.EventFilters.multi_event(typed(:string, "Hello"))

      assert {:ok, [%Ethers.Event{address: ^address, topics: ["MultiEvent(string)", _]}]} =
               Ethers.get_logs(string_filter, address: address)

      string_filter = MultiClauseContract.EventFilters.multi_event(typed(:string, "Good Bye"))

      assert {:ok, []} = Ethers.get_logs(string_filter, address: address)
    end

    test "listens on the right event with nil values", %{address: address} do
      MultiClauseContract.emit_event(typed({:uint, 256}, 10))
      |> Ethers.send_transaction!(to: address, from: @from)
      |> wait_for_transaction!()

      uint_filter = MultiClauseContract.EventFilters.multi_event(typed({:uint, 256}, nil))

      assert {:ok, [%Ethers.Event{address: ^address, topics: ["MultiEvent(uint256)", 10]}]} =
               Ethers.get_logs(uint_filter, address: address)

      MultiClauseContract.emit_event(typed({:int, 256}, -20))
      |> Ethers.send_transaction!(to: address, from: @from)
      |> wait_for_transaction!()

      int_filter = MultiClauseContract.EventFilters.multi_event(typed({:int, 256}, nil))

      assert {:ok, [%Ethers.Event{address: ^address, topics: ["MultiEvent(int256)", -20]}]} =
               Ethers.get_logs(int_filter, address: address)
    end

    test "raises on conflicting parameters" do
      assert_raise ArgumentError,
                   ~s'Ambiguous parameters\n\n## Arguments\n~c"\\n"\n\n## Possible signatures\nMultiEvent(uint256 n)\nMultiEvent(int256 n)\n',
                   fn ->
                     MultiClauseContract.EventFilters.multi_event(10)
                   end
    end

    test "renders correct values when inspected" do
      uint_filter = MultiClauseContract.EventFilters.multi_event(typed({:uint, 256}, nil))
      int_filter = MultiClauseContract.EventFilters.multi_event(-30)
      string_filter = MultiClauseContract.EventFilters.multi_event("value to filter")

      assert "#Ethers.EventFilter<event MultiEvent(uint256 indexed n any)>" ==
               inspect(uint_filter)

      assert "#Ethers.EventFilter<event MultiEvent(int256 indexed n -30)>" == inspect(int_filter)

      assert ~s'#Ethers.EventFilter<event MultiEvent(string indexed n (hashed) "0xa842b64ae579814ab0eb0812f6cf54815c20796d31e248113583d3cf17d7eef4")>' ==
               inspect(string_filter)
    end
  end

  defp deploy_multi_clause_contract(_ctx) do
    encoded_constructor = MultiClauseContract.constructor()

    address = deploy(MultiClauseContract, encoded_constructor: encoded_constructor, from: @from)

    [address: address]
  end
end
