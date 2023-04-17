defmodule Ethers.RegistryContractTest do
  use ExUnit.Case
  doctest Ethers.Contract

  alias Ethers.Contract.Test.RegistryContract

  @from "0x90F8bf6A479f320ead074411a4B0e7944Ea8c9C1"

  describe "contract deployment" do
    test "Can deploy contract without constructor on blockchain" do
      init_params = RegistryContract.constructor()
      assert {:ok, tx_hash} = Ethers.deploy(RegistryContract, init_params, %{from: @from})
      assert {:ok, _address} = Ethers.deployed_address(tx_hash)
    end
  end

  describe "can send and receive structs" do
    setup :deploy_registry_contract

    test "can send transaction with structs", %{address: address} do
      {:ok, _tx_hash} = RegistryContract.register({"alisina", 27}, from: @from, to: address)
    end

    test "can call functions returning structs", %{address: address} do
      {:ok, [{"", 0}]} = RegistryContract.info(@from, to: address)

      {:ok, _tx_hash} = RegistryContract.register({"alisina", 27}, from: @from, to: address)

      {:ok, [{"alisina", 27}]} = RegistryContract.info(@from, to: address)
    end
  end

  defp deploy_registry_contract(_ctx) do
    init_params = RegistryContract.constructor()
    assert {:ok, tx_hash} = Ethers.deploy(RegistryContract, init_params, %{from: @from})
    assert {:ok, address} = Ethers.deployed_address(tx_hash)

    [address: address]
  end
end
