defmodule Ethers.Contract.Test.CounterContract do
  @moduledoc false
  use Ethers.Contract, abi_file: "tmp/counter_abi.json"
end

defmodule Ethers.CounterContractTest do
  use ExUnit.Case
  doctest Ethers.Contract

  alias Ethers.Event

  alias Ethers.Contract.Test.CounterContract

  @from "0x90F8bf6A479f320ead074411a4B0e7944Ea8c9C1"

  describe "contract deployment" do
    test "Can deploy a contract on blockchain" do
      init_params = CounterContract.constructor(100)
      assert {:ok, tx_hash} = Ethers.deploy(CounterContract, init_params, %{from: @from})
      assert {:ok, _address} = Ethers.deployed_address(tx_hash)
    end
  end

  describe "calling functions with default action" do
    setup :deploy_counter_contract

    test "calling view functions", %{address: address} do
      {:ok, [100]} = CounterContract.get(to: address)
      [100] = CounterContract.get!(to: address)
    end

    test "sending transaction with state mutating functions", %{address: address} do
      {:ok, _tx_hash} = CounterContract.set(101, from: @from, to: address)

      {:ok, [101]} = CounterContract.get(to: address)
    end

    test "sending transaction with state mutating functions using bang functions", %{
      address: address
    } do
      _tx_hash = CounterContract.set!(101, from: @from, to: address)

      [101] = CounterContract.get!(to: address)
    end

    test "returns error if to address is not given" do
      {:error, :no_to_address} = CounterContract.get()
    end

    test "returns the gas estimate with :estimate_gas action", %{address: address} do
      assert {:ok, gas_estimate} =
               CounterContract.set(101, from: @from, to: address, action: :estimate_gas)

      assert is_integer(gas_estimate)

      # Same with the bang function
      assert gas_estimate ==
               CounterContract.set!(101, from: @from, to: address, action: :estimate_gas)
    end

    test "returns the params when called with :prepare action", %{address: address} do
      assert {:ok,
              %{
                data:
                  "0x60fe47b10000000000000000000000000000000000000000000000000000000000000065",
                to: ^address,
                from: @from
              }} =
               CounterContract.set(101, from: @from, to: address, action: :prepare)
    end

    test "can use prepare params in call and send functions from RPC", %{address: address} do
      assert {:ok, send_params} =
               CounterContract.set(101, from: @from, to: address, action: :prepare)

      assert {:ok, _tx_hash} = Ethers.RPC.send(send_params)

      assert {:ok, call_params} = CounterContract.get(to: address, action: :prepare)
      assert {:ok, [101]} == Ethers.RPC.call(call_params)
    end

    test "raises error when given invalid action", %{address: address} do
      assert_raise ArgumentError, "Invalid action: :invalid", fn ->
        CounterContract.set(101, from: @from, to: address, action: :invalid)
      end
    end

    test "does not work without to address" do
      assert {:error, :no_to_address} = CounterContract.set(101, from: @from)
      assert {:error, :no_to_address} = CounterContract.get()
    end
  end

  describe "Event filter works with get_logs" do
    setup :deploy_counter_contract

    test "can get the emitted event with the correct filter", %{address: address} do
      {:ok, _tx_hash} = CounterContract.set(101, from: @from, to: address)

      assert open_filter = CounterContract.EventFilters.set_called(nil)
      assert correct_filter = CounterContract.EventFilters.set_called(100)
      assert incorrect_filter = CounterContract.EventFilters.set_called(105)

      assert {:ok,
              [
                %Event{
                  address: ^address,
                  topics: ["SetCalled(uint256,uint256)", 100],
                  data: [101]
                }
              ]} = Ethers.get_logs(open_filter)

      assert {:ok, [%Event{address: ^address, data: [101]}]} = Ethers.get_logs(correct_filter)
      assert {:ok, []} = Ethers.get_logs(incorrect_filter)
    end
  end

  describe "override block number" do
    setup :deploy_counter_contract

    test "can call a view function on a previous block", %{address: address} do
      {:ok, _tx_hash} = CounterContract.set(101, from: @from, to: address)
      {:ok, block_1} = Ethereumex.HttpClient.eth_block_number()

      {:ok, _tx_hash} = CounterContract.set(102, from: @from, to: address)
      {:ok, block_2} = Ethereumex.HttpClient.eth_block_number()

      {:ok, _tx_hash} = CounterContract.set(103, from: @from, to: address)

      assert CounterContract.get!(to: address, block: "latest") == [103]
      assert CounterContract.get!(to: address, block: block_2) == [102]
      assert CounterContract.get!(to: address, block: block_1) == [101]
    end
  end

  defp deploy_counter_contract(_ctx) do
    init_params = CounterContract.constructor(100)
    assert {:ok, tx_hash} = Ethers.deploy(CounterContract, init_params, %{from: @from})
    assert {:ok, address} = Ethers.deployed_address(tx_hash)

    [address: address]
  end
end
