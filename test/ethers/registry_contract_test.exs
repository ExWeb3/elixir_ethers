defmodule Ethers.Contract.Test.RegistryContract do
  @moduledoc false
  use Ethers.Contract, abi_file: "tmp/registry_abi.json"
end

defmodule Ethers.RegistryContractTest do
  use ExUnit.Case
  doctest Ethers.Contract

  alias Ethers.Contract.Test.RegistryContract

  @from "0x90f8bf6a479f320ead074411a4b0e7944ea8c9c1"

  setup :deploy_registry_contract

  describe "can send and receive structs" do
    test "can send transaction with structs", %{address: address} do
      {:ok, _tx_hash} =
        RegistryContract.register({"alisina", 27}) |> Ethers.send(from: @from, to: address)
    end

    test "can call functions returning structs", %{address: address} do
      {:ok, {"", 0}} = RegistryContract.info(@from) |> Ethers.call(to: address)

      {:ok, _tx_hash} =
        RegistryContract.register({"alisina", 27}) |> Ethers.send(from: @from, to: address)

      {:ok, {"alisina", 27}} = RegistryContract.info(@from) |> Ethers.call(to: address)
    end
  end

  describe "event filters" do
    test "can create event filters and fetch register events", %{address: address} do
      {:ok, _tx_hash} =
        RegistryContract.register({"alisina", 27}) |> Ethers.send(from: @from, to: address)

      empty_filter = RegistryContract.EventFilters.registered(nil)
      search_filter = RegistryContract.EventFilters.registered(@from)

      assert {:ok, [%Ethers.Event{address: ^address}]} = Ethers.get_logs(empty_filter)

      assert {:ok,
              [%{topics: ["Registered(address,(string,uint8))", @from], data: [{"alisina", 27}]}]} =
               Ethers.get_logs(search_filter)
    end

    test "does not return any events for a non existing contract", %{address: address} do
      {:ok, _tx_hash} =
        RegistryContract.register({"alisina", 27}) |> Ethers.send(from: @from, to: address)

      empty_filter = RegistryContract.EventFilters.registered(nil)

      assert {:ok, [%Ethers.Event{address: ^address}]} =
               Ethers.get_logs(empty_filter, address: address)

      assert {:ok, []} = Ethers.get_logs(empty_filter, address: @from)
    end
  end

  defp deploy_registry_contract(_ctx) do
    init_params = RegistryContract.constructor()
    assert {:ok, tx_hash} = Ethers.deploy(RegistryContract, init_params, %{from: @from})
    assert {:ok, address} = Ethers.deployed_address(tx_hash)

    [address: address]
  end
end
