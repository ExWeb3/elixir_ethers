defmodule Ethers.Contract.Test.RegistryContract do
  @moduledoc false
  use Ethers.Contract, abi_file: "tmp/registry_abi.json"
end

defmodule Ethers.RegistryContractTest do
  use ExUnit.Case
  doctest Ethers.Contract

  import Ethers.TestHelpers

  alias Ethers.Contract.Test.RegistryContract

  @from "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266"
  @from1 "0x70997970C51812dc3A010C7d01b50e0d17dc79C8"
  @from2 "0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC"

  setup :deploy_registry_contract

  describe "can send and receive structs" do
    test "can send transaction with structs", %{address: address} do
      RegistryContract.register({"alisina", 27})
      |> Ethers.send_transaction!(from: @from, to: address)
      |> wait_for_transaction!()
    end

    test "can call functions returning structs", %{address: address} do
      {:ok, {"", 0}} = RegistryContract.info(@from) |> Ethers.call(to: address)

      RegistryContract.register({"alisina", 27})
      |> Ethers.send_transaction!(from: @from, to: address)
      |> wait_for_transaction!()

      {:ok, {"alisina", 27}} = RegistryContract.info(@from) |> Ethers.call(to: address)
    end
  end

  describe "can handle tuples and arrays" do
    test "can call functions returning array of structs", %{address: address} do
      RegistryContract.register({"alisina", 27})
      |> Ethers.send_transaction!(from: @from, to: address)
      |> wait_for_transaction!()

      RegistryContract.register({"bob", 13})
      |> Ethers.send_transaction!(from: @from1, to: address)
      |> wait_for_transaction!()

      RegistryContract.register({"blaze", 37})
      |> Ethers.send_transaction!(from: @from2, to: address)
      |> wait_for_transaction!()

      {:ok, [{"alisina", 27}, {"bob", 13}, {"blaze", 37}]} =
        RegistryContract.info_many([@from, @from1, @from2]) |> Ethers.call(to: address)
    end

    test "can call functions returning tuple", %{address: address} do
      RegistryContract.register({"alisina", 27})
      |> Ethers.send_transaction!(from: @from, to: address)
      |> wait_for_transaction!()

      {:ok, ["alisina", 27]} = RegistryContract.info_as_tuple(@from) |> Ethers.call(to: address)
    end
  end

  describe "event filters" do
    test "can create event filters and fetch register events", %{address: address} do
      RegistryContract.register({"alisina", 27})
      |> Ethers.send_transaction!(from: @from, to: address)
      |> wait_for_transaction!()

      empty_filter = RegistryContract.EventFilters.registered(nil)
      search_filter = RegistryContract.EventFilters.registered(@from)

      assert {:ok, [%Ethers.Event{address: ^address}]} = Ethers.get_logs(empty_filter)

      assert {:ok,
              [%{topics: ["Registered(address,(string,uint8))", @from], data: [{"alisina", 27}]}]} =
               Ethers.get_logs(search_filter)
    end

    test "does not return any events for a non existing contract", %{address: address} do
      RegistryContract.register({"alisina", 27})
      |> Ethers.send_transaction!(from: @from, to: address)
      |> wait_for_transaction!()

      empty_filter = RegistryContract.EventFilters.registered(nil)

      assert {:ok, [%Ethers.Event{address: ^address}]} =
               Ethers.get_logs(empty_filter, address: address)

      assert {:ok, []} = Ethers.get_logs(empty_filter, address: @from)
    end
  end

  defp deploy_registry_contract(_ctx) do
    address =
      deploy(RegistryContract, encoded_constructor: RegistryContract.constructor(), from: @from)

    [address: address]
  end
end
