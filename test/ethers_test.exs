defmodule Ethers.Contract.Test.HelloWorldContract do
  @moduledoc false
  use Ethers.Contract, abi_file: "tmp/hello_world_abi.json"
end

defmodule Ethers.Contract.Test.HelloWorldWithDefaultAddressContract do
  @moduledoc false
  use Ethers.Contract,
    abi_file: "tmp/hello_world_abi.json",
    default_address: "0x1000bf6a479f320ead074411a4b0e7944ea8c9c1"
end

defmodule EthersTest do
  use ExUnit.Case
  doctest Ethers

  alias Ethers.Contract.Test.HelloWorldContract
  alias Ethers.Contract.Test.HelloWorldWithDefaultAddressContract
  alias Ethers.ExecutionError

  @from "0x90f8bf6a479f320ead074411a4b0e7944ea8c9c1"

  describe "current_gas_price" do
    test "returns the correct gas price" do
      assert {:ok, 2_000_000_000} = Ethers.current_gas_price()
    end
  end

  describe "current_block_number" do
    test "returns the current block number" do
      assert {:ok, n} = Ethers.current_block_number()
      assert n >= 0
    end

    test "can override the rpc options" do
      assert {:ok, 1001} ==
               Ethers.current_block_number(
                 rpc_client: Ethers.TestRPCModule,
                 rpc_opts: [block: "0x3E9"]
               )
    end
  end

  describe "contract deployment" do
    test "can deploy a contract given a module which has the binary" do
      assert {:ok, tx} = Ethers.deploy(HelloWorldContract, from: @from)
      assert {:ok, contract_address} = Ethers.deployed_address(tx)

      assert HelloWorldContract.say_hello() |> Ethers.call!(to: contract_address) ==
               "Hello World!"
    end

    test "can deploy a contract given the contract binary" do
      bin = HelloWorldContract.__contract_binary__()
      assert {:ok, tx} = Ethers.deploy(bin, from: @from)
      assert {:ok, contract_address} = Ethers.deployed_address(tx)

      assert HelloWorldContract.say_hello() |> Ethers.call!(to: contract_address) ==
               "Hello World!"
    end

    test "can deploy a contract given the contract binary prefixed with 0x" do
      bin = HelloWorldContract.__contract_binary__()
      assert {:ok, tx} = Ethers.deploy("0x" <> bin, from: @from)
      assert {:ok, contract_address} = Ethers.deployed_address(tx)

      assert HelloWorldContract.say_hello() |> Ethers.call!(to: contract_address) ==
               "Hello World!"
    end

    test "returns error if the module does not include the binary" do
      assert {:error, :binary_not_found} = Ethers.deploy(NotFoundContract, from: @from)

      assert {:error, :binary_not_found} =
               Ethers.deploy(Ethers.Contracts.ERC20, from: @from)
    end

    test "getting the deployed address of a non existing (not yet validated) transaction" do
      tx_hash = "0x5c504ed432cb51138bcf09aa5e8a410dd4a1e204ef84bfed1be16dfba1b22060"
      assert {:error, :transaction_not_found} = Ethers.deployed_address(tx_hash)
    end

    test "getting the deployed address of a non contract creation transaction" do
      {:ok, tx} = Ethers.deploy(HelloWorldContract, from: @from)
      {:ok, contract_address} = Ethers.deployed_address(tx)

      {:ok, tx_hash} =
        HelloWorldContract.set_hello("Bye") |> Ethers.send(to: contract_address, from: @from)

      assert {:error, :no_contract_address} = Ethers.deployed_address(tx_hash)

      assert HelloWorldContract.say_hello() |> Ethers.call!(to: contract_address) ==
               "Bye"
    end
  end

  describe "get_logs/2" do
    test "returns error when request fails" do
      assert {:error, %{reason: :nxdomain}} =
               Ethers.get_logs(%{topics: [], selector: nil},
                 rpc_opts: [url: "http://non.exists"]
               )
    end

    test "with bang function, raises error when request fails" do
      assert_raise Mint.TransportError, "non-existing domain", fn ->
        Ethers.get_logs!(%{topics: [], selector: nil},
          rpc_opts: [url: "http://non.exists"]
        )
      end
    end
  end

  describe "default address" do
    test "is included in the function calls when has default address" do
      assert %Ethers.TxData{
               data: "0xef5fb05b",
               selector: %ABI.FunctionSelector{
                 function: "sayHello",
                 method_id: <<239, 95, 176, 91>>,
                 type: :function,
                 inputs_indexed: nil,
                 state_mutability: :view,
                 input_names: [],
                 types: [],
                 returns: [:string],
                 return_names: [""]
               },
               default_address: "0x1000bf6a479f320ead074411a4b0e7944ea8c9c1"
             } == HelloWorldWithDefaultAddressContract.say_hello()

      assert %{data: "0xef5fb05b", to: "0x1000bf6a479f320ead074411a4b0e7944ea8c9c1"} ==
               HelloWorldWithDefaultAddressContract.say_hello()
               |> Ethers.TxData.to_map([])
    end

    test "is not included in the function calls when does not have default address" do
      assert %Ethers.TxData{
               data: "0xef5fb05b",
               selector: %ABI.FunctionSelector{
                 function: "sayHello",
                 method_id: <<239, 95, 176, 91>>,
                 type: :function,
                 inputs_indexed: nil,
                 state_mutability: :view,
                 input_names: [],
                 types: [],
                 returns: [:string],
                 return_names: [""]
               },
               default_address: nil
             } == HelloWorldContract.say_hello()
    end

    test "is included in event filters when has default address" do
      assert %Ethers.EventFilter{
               topics: [
                 "0xbe6cf5e99b344c66895d6304d442b2f51b6359ee51ac581db2255de9373e24b8"
               ],
               selector: %ABI.FunctionSelector{
                 function: "HelloSet",
                 method_id: <<190, 108, 245, 233>>,
                 type: :event,
                 inputs_indexed: [false],
                 state_mutability: nil,
                 input_names: ["message"],
                 types: [:string],
                 returns: []
               },
               default_address: "0x1000bf6a479f320ead074411a4b0e7944ea8c9c1"
             } == HelloWorldWithDefaultAddressContract.EventFilters.hello_set()

      assert %{
               topics: ["0xbe6cf5e99b344c66895d6304d442b2f51b6359ee51ac581db2255de9373e24b8"],
               address: "0x1000bf6a479f320ead074411a4b0e7944ea8c9c1"
             } ==
               HelloWorldWithDefaultAddressContract.EventFilters.hello_set()
               |> Ethers.EventFilter.to_map([])
    end

    test "is not included in event filters when does not have default address" do
      assert %Ethers.EventFilter{
               topics: [
                 "0xbe6cf5e99b344c66895d6304d442b2f51b6359ee51ac581db2255de9373e24b8"
               ],
               selector: %ABI.FunctionSelector{
                 function: "HelloSet",
                 method_id: <<190, 108, 245, 233>>,
                 type: :event,
                 inputs_indexed: [false],
                 state_mutability: nil,
                 input_names: ["message"],
                 types: [:string],
                 returns: []
               },
               default_address: nil
             } == HelloWorldContract.EventFilters.hello_set()
    end
  end

  describe "batch/2" do
    test "Can batch multiple requests" do
      assert {:ok, tx} = Ethers.deploy(HelloWorldContract, from: @from)
      assert {:ok, address} = Ethers.deployed_address(tx)

      HelloWorldContract.set_hello("Hello Batch!")
      |> Ethers.send!(to: address, from: @from)

      assert {:ok, results} =
               Ethers.batch([
                 {:call, HelloWorldContract.say_hello(), to: address},
                 {:send, HelloWorldContract.set_hello("hi"), from: @from, to: address},
                 :net_version,
                 {:estimate_gas, HelloWorldContract.say_hello(), to: address},
                 {:get_logs, HelloWorldContract.EventFilters.hello_set(), address: address},
                 :current_block_number,
                 :current_gas_price
               ])

      assert [
               ok: "Hello Batch!",
               ok: "0x" <> _hash,
               ok: <<_net_version::binary>>,
               ok: gas_estimate,
               ok: [%Ethers.Event{}],
               ok: block_number,
               ok: gas_price
             ] = results

      assert is_integer(gas_estimate)
      assert is_integer(block_number)
      assert is_integer(gas_price)
    end

    test "returns error for invalid action" do
      assert {:error, :no_to_address} = Ethers.batch([{:call, HelloWorldContract.say_hello()}])
    end
  end

  describe "batch!/2" do
    test "returns the correct result" do
      assert {:ok, tx} = Ethers.deploy(HelloWorldContract, from: @from)
      assert {:ok, address} = Ethers.deployed_address(tx)

      assert [ok: "Hello World!", ok: _] =
               Ethers.batch!([
                 {:call, HelloWorldContract.say_hello(), to: address},
                 :current_block_number
               ])

      assert_raise ExecutionError, "Unexpected error: no_to_address", fn ->
        Ethers.batch!([{:call, HelloWorldContract.say_hello()}])
      end
    end
  end
end
