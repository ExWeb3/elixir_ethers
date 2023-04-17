defmodule Ethers.ContractTest do
  use ExUnit.Case
  doctest Ethers.Contract

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
    end

    test "sending transaction with state mutating functions", %{address: address} do
      {:ok, _tx_hash} = CounterContract.set(101, from: @from, to: address)

      {:ok, [101]} = CounterContract.get(to: address)
    end
  end

  describe "Event filter works with get_logs" do
    setup :deploy_counter_contract

    test "can get the emitted event with the correct filter", %{address: address} do
      {:ok, _tx_hash} = CounterContract.set(101, from: @from, to: address)

      {:ok, open_filter} = CounterContract.EventFilters.set_called(nil)

      {:ok, correct_filter} = CounterContract.EventFilters.set_called(100)

      {:ok, incorrect_filter} = CounterContract.EventFilters.set_called(105)

      {:ok, [%{"address" => ^address, "data" => [101]}]} = Ethers.get_logs(open_filter)
      {:ok, [%{"address" => ^address, "data" => [101]}]} = Ethers.get_logs(correct_filter)
      {:ok, []} = Ethers.get_logs(incorrect_filter)
    end
  end

  defp deploy_counter_contract(_ctx) do
    init_params = CounterContract.constructor(100)
    assert {:ok, tx_hash} = Ethers.deploy(CounterContract, init_params, %{from: @from})
    assert {:ok, address} = Ethers.deployed_address(tx_hash)

    [address: address]
  end
end
