defmodule Ethers.MulticallTest do
  use ExUnit.Case

  import Ethers.Utils, only: [hex_decode!: 1]

  alias Ethers.Contract.Test.CounterContract
  alias Ethers.Contract.Test.HelloWorldContract
  alias Ethers.Contracts.Multicall3
  alias Ethers.Multicall

  @from "0x90f8bf6a479f320ead074411a4b0e7944ea8c9c1"

  describe "multicall3" do
    setup :deploy_contracts

    test "multiple calls with no default address using Ethers.call", %{
      counter_address: counter_address,
      hello_world_address: hello_world_address
    } do
      [
        {HelloWorldContract.say_hello(), to: hello_world_address}
      ]
      |> Multicall.aggregate3()
      |> Ethers.call!()
      |> Multicall.decode([
        HelloWorldContract.say_hello()
      ])
      |> IO.inspect()
    end

    test "multiple calls with no default address and using Multicall.call", %{
      counter_address: counter_address,
      hello_world_address: hello_world_address
    } do
      [
        {HelloWorldContract.say_hello(), to: hello_world_address}
      ]
      |> Multicall.aggregate3()
      |> Ethers.call!()
      |> Multicall.decode([
        HelloWorldContract.say_hello()
      ])
      |> IO.inspect()
    end

    test "multiple calls with reduced abstraction", %{
      counter_address: counter_address,
      hello_world_address: hello_world_address
    } do
      {:ok, [true: "Hello World!", true: 420]} =
        [
          {hello_world_address, true, hex_decode!("0xef5fb05b")},
          {hello_world_address, true, hex_decode!("0x6d4ce63c")},
          {counter_address, true, hex_decode!("0x6d4ce63c")},
          {counter_address, true, hex_decode!("0xef5fb05b")}
        ]
        |> Multicall3.aggregate3()
        |> Ethers.call()
    end
  end

  defp deploy_contracts(_ctx) do
    init_params = CounterContract.constructor(420)
    assert {:ok, tx_hash} = Ethers.deploy(CounterContract, init_params, %{from: @from})
    assert {:ok, counter_address} = Ethers.deployed_address(tx_hash)

    assert {:ok, tx_hash} = Ethers.deploy(HelloWorldContract, "", %{from: @from})
    assert {:ok, hello_world_address} = Ethers.deployed_address(tx_hash)

    [
      counter_address: counter_address,
      hello_world_address: hello_world_address
    ]
  end
end
