defmodule Ethers.EventTest do
  use ExUnit.Case
  alias Ethers.Event
  doctest Event

  describe "decode/2" do
    test "indexed bytes topic is returned as a hex-encoded keccak hash" do
      selector = %ABI.FunctionSelector{
        function: "SetLiquidityAdapterAndData",
        method_id:
          <<0x9D, 0xEB, 0x43, 0xD7, 0x14, 0x22, 0xAF, 0x41, 0x85, 0x3C, 0x39, 0x21, 0xFB, 0x36,
            0x4B, 0x76, 0x47, 0xF9, 0xA9, 0xB1, 0x36, 0xE4, 0x6D, 0x66, 0xD4, 0x5C, 0x1B, 0xF7,
            0x07, 0xAF, 0x70, 0x6C>>,
        type: :event,
        inputs_indexed: [true, true, true],
        state_mutability: nil,
        input_names: ["sender", "newLiquidityAdapter", "newLiquidityData"],
        types: [:address, :address, :bytes],
        returns: []
      }

      assert %Ethers.Event{
               topics: [
                 _method,
                 "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
                 "0x607Bca5681cEe20C82cF1D899E60B9eD36bc611C",
                 "0x64d65c9a2d91c36d56fbc42d69e979335320169b3df63bf92789e2c8883fcc64"
               ]
             } =
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
                     "0x9deb43d71422af41853c3921fb364b7647f9a9b136e46d66d45c1bf707af706c",
                     "0x000000000000000000000000f39fd6e51aad88f6f4ce6ab8827279cfffb92266",
                     "0x000000000000000000000000607bca5681cee20c82cf1d899e60b9ed36bc611c",
                     "0x64d65c9a2d91c36d56fbc42d69e979335320169b3df63bf92789e2c8883fcc64"
                   ],
                   "transactionHash" =>
                     "0xf6e06e4f3fbd67088e8278843e55862957537760c63bae7b682a0e39da75b45d",
                   "transactionIndex" => "0x83"
                 },
                 selector
               )
    end

    test "indexed string topic is returned as a hex-encoded keccak hash" do
      selector = %ABI.FunctionSelector{
        function: "E",
        method_id: :binary.copy(<<0>>, 32),
        type: :event,
        inputs_indexed: [true],
        state_mutability: nil,
        input_names: ["name"],
        types: [:string],
        returns: []
      }

      assert %Ethers.Event{
               topics: [
                 _method,
                 "0x64d65c9a2d91c36d56fbc42d69e979335320169b3df63bf92789e2c8883fcc64"
               ]
             } =
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
                     "0x0000000000000000000000000000000000000000000000000000000000000000",
                     "0x64d65c9a2d91c36d56fbc42d69e979335320169b3df63bf92789e2c8883fcc64"
                   ],
                   "transactionHash" =>
                     "0xf6e06e4f3fbd67088e8278843e55862957537760c63bae7b682a0e39da75b45d",
                   "transactionIndex" => "0x83"
                 },
                 selector
               )
    end

    test "indexed dynamic array topic is returned as a hex-encoded keccak hash" do
      selector = %ABI.FunctionSelector{
        function: "E",
        method_id: :binary.copy(<<0>>, 32),
        type: :event,
        inputs_indexed: [true],
        state_mutability: nil,
        input_names: ["xs"],
        types: [{:array, {:uint, 256}}],
        returns: []
      }

      assert %Ethers.Event{
               topics: [
                 _method,
                 "0xabcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789"
               ]
             } =
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
                     "0x0000000000000000000000000000000000000000000000000000000000000000",
                     "0xabcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789"
                   ],
                   "transactionHash" =>
                     "0xf6e06e4f3fbd67088e8278843e55862957537760c63bae7b682a0e39da75b45d",
                   "transactionIndex" => "0x83"
                 },
                 selector
               )
    end

    test "indexed tuple topic is returned as a hex-encoded keccak hash" do
      selector = %ABI.FunctionSelector{
        function: "E",
        method_id: :binary.copy(<<0>>, 32),
        type: :event,
        inputs_indexed: [true],
        state_mutability: nil,
        input_names: ["s"],
        types: [{:tuple, [{:uint, 256}, :address]}],
        returns: []
      }

      assert %Ethers.Event{
               topics: [
                 _method,
                 "0x1111111111111111111111111111111111111111111111111111111111111111"
               ]
             } =
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
                     "0x0000000000000000000000000000000000000000000000000000000000000000",
                     "0x1111111111111111111111111111111111111111111111111111111111111111"
                   ],
                   "transactionHash" =>
                     "0xf6e06e4f3fbd67088e8278843e55862957537760c63bae7b682a0e39da75b45d",
                   "transactionIndex" => "0x83"
                 },
                 selector
               )
    end

    test "mixed indexed bytes and non-indexed uint256 decodes both" do
      selector = %ABI.FunctionSelector{
        function: "E",
        method_id: :binary.copy(<<0>>, 32),
        type: :event,
        inputs_indexed: [true, true, false],
        state_mutability: nil,
        input_names: ["a", "b", "nonIndexed"],
        types: [:address, :bytes, {:uint, 256}],
        returns: [uint: 256]
      }

      assert %Ethers.Event{
               data: [42],
               topics: [
                 _method,
                 "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
                 "0x64d65c9a2d91c36d56fbc42d69e979335320169b3df63bf92789e2c8883fcc64"
               ]
             } =
               Event.decode(
                 %{
                   "address" => "0xaa107ccfe230a29c345fd97bc6eb9bd2fccd0750",
                   "blockHash" =>
                     "0xe8885761ec559c5e267c48f44b4b12e4169f7d3a116f5e8f43314147722f0d83",
                   "blockNumber" => "0x1138b39",
                   "data" => "0x000000000000000000000000000000000000000000000000000000000000002a",
                   "logIndex" => "0x1a1",
                   "removed" => false,
                   "topics" => [
                     "0x0000000000000000000000000000000000000000000000000000000000000000",
                     "0x000000000000000000000000f39fd6e51aad88f6f4ce6ab8827279cfffb92266",
                     "0x64d65c9a2d91c36d56fbc42d69e979335320169b3df63bf92789e2c8883fcc64"
                   ],
                   "transactionHash" =>
                     "0xf6e06e4f3fbd67088e8278843e55862957537760c63bae7b682a0e39da75b45d",
                   "transactionIndex" => "0x83"
                 },
                 selector
               )
    end

    test "decode log with no data returns empty list" do
      selector = %ABI.FunctionSelector{
        function: "Approval",
        method_id: <<140, 91, 225, 229>>,
        type: :event,
        inputs_indexed: [true, true, true],
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

  describe "find_and_decode/2" do
    test "finds correct selector and decodes log" do
      assert {:ok, %Ethers.Event{data: [3831]}} =
               Event.find_and_decode(
                 %{
                   "address" => "0xaa107ccfe230a29c345fd97bc6eb9bd2fccd0750",
                   "blockHash" =>
                     "0xe8885761ec559c5e267c48f44b4b12e4169f7d3a116f5e8f43314147722f0d83",
                   "blockNumber" => "0x1138b39",
                   "data" => "0x0000000000000000000000000000000000000000000000000000000000000ef7",
                   "logIndex" => "0x1a1",
                   "removed" => false,
                   "topics" => [
                     "0x8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b925",
                     "0x00000000000000000000000023c5d7a16cf2e14a00f1c81be9443259f3cbc4ce",
                     "0x0000000000000000000000000000000000000000000000000000000000000000"
                   ],
                   "transactionHash" =>
                     "0xf6e06e4f3fbd67088e8278843e55862957537760c63bae7b682a0e39da75b45d",
                   "transactionIndex" => "0x83"
                 },
                 Ethers.Contracts.ERC20.EventFilters
               )
    end
  end
end
