defmodule Ethers.Contract.Test.MultiClauseContract do
  @moduledoc false
  use Ethers.Contract, abi_file: "tmp/multi_clause_abi.json"
end

defmodule Ethers.MultiClauseContractTest do
  use ExUnit.Case

  alias Ethers.Contract.Test.MultiClauseContract

  import Ethers.Types, only: [typed: 2]

  @from "0x90f8bf6a479f320ead074411a4b0e7944ea8c9c1"

  setup :deploy_multi_clause_contract

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
      assert ["uint256"] ==
               MultiClauseContract.say(typed({:uint, 256}, 101)) |> Ethers.call!(to: address)

      assert ["int256"] ==
               MultiClauseContract.say(typed({:int, 256}, 101)) |> Ethers.call!(to: address)

      assert ["int256"] ==
               MultiClauseContract.say(typed({:int, 256}, 101)) |> Ethers.call!(to: address)
    end
  end

  describe "smart function" do
    test "can deduce type based on properties", %{address: address} do
      assert ["uint8"] == MultiClauseContract.smart(255) |> Ethers.call!(to: address)
      assert ["int8"] == MultiClauseContract.smart(-1) |> Ethers.call!(to: address)
    end
  end

  describe "multi clause events" do
    test "listens on the right event", %{address: address} do
      MultiClauseContract.emit_event(typed({:uint, 256}, 10))
      |> Ethers.send!(to: address, from: @from)

      uint_filter = MultiClauseContract.EventFilters.multi_event(typed({:uint, 256}, 10))

      assert {:ok, [%Ethers.Event{address: ^address, topics: ["MultiEvent(uint256)", 10]}]} =
               Ethers.get_logs(uint_filter, address: address)

      MultiClauseContract.emit_event(typed({:int, 256}, -20))
      |> Ethers.send!(to: address, from: @from)

      int_filter = MultiClauseContract.EventFilters.multi_event(typed({:int, 256}, -20))

      assert {:ok, [%Ethers.Event{address: ^address, topics: ["MultiEvent(int256)", -20]}]} =
               Ethers.get_logs(int_filter, address: address)

      MultiClauseContract.emit_event("Hello")
      |> Ethers.send!(to: address, from: @from)

      string_filter = MultiClauseContract.EventFilters.multi_event(typed(:string, "Hello"))

      assert {:ok, [%Ethers.Event{address: ^address, topics: ["MultiEvent(string)", _]}]} =
               Ethers.get_logs(string_filter, address: address)

      string_filter = MultiClauseContract.EventFilters.multi_event(typed(:string, "Good Bye"))

      assert {:ok, []} = Ethers.get_logs(string_filter, address: address)
    end

    test "listens on the right event with nil values", %{address: address} do
      MultiClauseContract.emit_event(typed({:uint, 256}, 10))
      |> Ethers.send!(to: address, from: @from)

      uint_filter = MultiClauseContract.EventFilters.multi_event(typed({:uint, 256}, nil))

      assert {:ok, [%Ethers.Event{address: ^address, topics: ["MultiEvent(uint256)", 10]}]} =
               Ethers.get_logs(uint_filter, address: address)

      MultiClauseContract.emit_event(typed({:int, 256}, -20))
      |> Ethers.send!(to: address, from: @from)

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
    init_params = MultiClauseContract.constructor()
    assert {:ok, tx_hash} = Ethers.deploy(MultiClauseContract, init_params, %{from: @from})
    assert {:ok, address} = Ethers.deployed_address(tx_hash)

    [address: address]
  end
end
