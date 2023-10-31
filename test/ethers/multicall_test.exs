defmodule Ethers.MulticallTest do
  use ExUnit.Case

  import Ethers.Utils, only: [hex_decode!: 1]

  alias Ethers.Contract.Test.CounterContract
  alias Ethers.Contract.Test.HelloWorldContract
  alias Ethers.Contract.Test.HelloWorldWithDefaultAddressContract
  alias Ethers.Contracts.Multicall3
  alias Ethers.Multicall

  @from "0x90f8bf6a479f320ead074411a4b0e7944ea8c9c1"

  describe "multicall" do
    setup :deploy_contracts

    test "aggregate3 with no default address using Ethers.call", %{
      counter_address: counter_address,
      hello_world_address: hello_world_address
    } do
      [true: "Hello World!", true: 420, true: 420] =
        [
          {HelloWorldContract.say_hello(), to: hello_world_address},
          {CounterContract.get(), to: counter_address},
          {CounterContract.get(), to: counter_address, allow_failure: false}
        ]
        |> Multicall.aggregate3()
        |> Ethers.call!()
        |> Multicall.aggregate3_decode([
          HelloWorldContract.say_hello(),
          CounterContract.get(),
          CounterContract.get()
        ])
    end

    test "aggregate3 with default address" do
      [true: "", true: ""] =
        [
          {HelloWorldWithDefaultAddressContract.say_hello()},
          HelloWorldWithDefaultAddressContract.say_hello()
        ]
        |> Multicall.aggregate3()
        |> Ethers.call!()
        |> Multicall.aggregate3_decode([
          HelloWorldWithDefaultAddressContract.say_hello(),
          HelloWorldWithDefaultAddressContract.say_hello()
        ])
    end

    test "aggregate3 with reduced abstraction and no decoding", %{
      counter_address: counter_address,
      hello_world_address: hello_world_address
    } do
      {:ok,
       [
         true:
           <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
             0, 0, 0, 32, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
             0, 0, 0, 0, 0, 0, 0, 12, 72, 101, 108, 108, 111, 32, 87, 111, 114, 108, 100, 33, 0,
             0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>,
         false: "",
         true:
           <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
             0, 0, 1, 164>>,
         false: ""
       ]} =
        [
          {hello_world_address, true, hex_decode!("0xef5fb05b")},
          {hello_world_address, true, hex_decode!("0x6d4ce63c")},
          {counter_address, true, hex_decode!("0x6d4ce63c")},
          {counter_address, true, hex_decode!("0xef5fb05b")}
        ]
        |> Multicall3.aggregate3()
        |> Ethers.call()
    end

    test "aggregate2 with no default address using Ethers.call", %{
      counter_address: counter_address,
      hello_world_address: hello_world_address
    } do
      [block, ["Hello World!", 420, 420]] =
        [
          {HelloWorldContract.say_hello(), to: hello_world_address},
          {CounterContract.get(), to: counter_address},
          {CounterContract.get(), to: counter_address, allow_failure: false}
        ]
        |> Multicall.aggregate2()
        |> Ethers.call!()
        |> Multicall.aggregate2_decode([
          HelloWorldContract.say_hello(),
          CounterContract.get(),
          CounterContract.get()
        ])

      {:ok, expected_block} = Ethers.current_block_number()
      assert expected_block == block
    end

    test "aggregate2 with default address" do
      [block, ["", ""]] =
        [
          {HelloWorldWithDefaultAddressContract.say_hello()},
          HelloWorldWithDefaultAddressContract.say_hello()
        ]
        |> Multicall.aggregate2()
        |> Ethers.call!()
        |> Multicall.aggregate2_decode([
          HelloWorldWithDefaultAddressContract.say_hello(),
          HelloWorldWithDefaultAddressContract.say_hello()
        ])

      {:ok, expected_block} = Ethers.current_block_number()
      assert expected_block == block
    end

    test "aggregate2 with reduced abstraction and no decoding", %{
      counter_address: counter_address,
      hello_world_address: hello_world_address
    } do
      {:ok,
       [
         block,
         [
           <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
             0, 0, 0, 32, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
             0, 0, 0, 0, 0, 0, 0, 12, 72, 101, 108, 108, 111, 32, 87, 111, 114, 108, 100, 33, 0,
             0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>,
           <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
             0, 0, 1, 164>>
         ]
       ]} =
        [
          {hello_world_address, hex_decode!("0xef5fb05b")},
          {counter_address, hex_decode!("0x6d4ce63c")}
        ]
        |> Multicall3.aggregate()
        |> Ethers.call()

      {:ok, expected_block} = Ethers.current_block_number()
      assert expected_block == block
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
