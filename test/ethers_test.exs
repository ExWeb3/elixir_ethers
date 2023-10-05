defmodule Ethers.Contract.Test.HelloWorldContract do
  @moduledoc false
  use Ethers.Contract, abi_file: "tmp/hello_world_abi.json"
end

defmodule EthersTest do
  use ExUnit.Case
  doctest Ethers

  alias Ethers.Contract.Test.HelloWorldContract

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
      assert {:ok, tx} = Ethers.deploy(HelloWorldContract, "", %{from: @from})
      assert {:ok, contract_address} = Ethers.deployed_address(tx)

      assert HelloWorldContract.say_hello() |> Ethers.call!(to: contract_address) == [
               "Hello World!"
             ]
    end

    test "can deploy a contract given the contract binary" do
      bin = HelloWorldContract.__contract_binary__()
      assert {:ok, tx} = Ethers.deploy(bin, "", %{from: @from})
      assert {:ok, contract_address} = Ethers.deployed_address(tx)

      assert HelloWorldContract.say_hello() |> Ethers.call!(to: contract_address) == [
               "Hello World!"
             ]
    end

    test "can deploy a contract given the contract binary prefixed with 0x" do
      bin = HelloWorldContract.__contract_binary__()
      assert {:ok, tx} = Ethers.deploy("0x" <> bin, "", %{from: @from})
      assert {:ok, contract_address} = Ethers.deployed_address(tx)

      assert HelloWorldContract.say_hello() |> Ethers.call!(to: contract_address) ==
               ["Hello World!"]
    end

    test "returns error if the module does not include the binary" do
      assert {:error, :binary_not_found} = Ethers.deploy(NotFoundContract, "", %{from: @from})

      assert {:error, :binary_not_found} =
               Ethers.deploy(Ethers.Contracts.ERC20, "", %{from: @from})
    end

    test "getting the deployed address of a non existing (not yet validated) transaction" do
      tx_hash = "0x5c504ed432cb51138bcf09aa5e8a410dd4a1e204ef84bfed1be16dfba1b22060"
      assert {:error, :transaction_not_found} = Ethers.deployed_address(tx_hash)
    end

    test "getting the deployed address of a non contract creation transaction" do
      {:ok, tx} = Ethers.deploy(HelloWorldContract, "", %{from: @from})
      {:ok, contract_address} = Ethers.deployed_address(tx)

      {:ok, tx_hash} =
        HelloWorldContract.set_hello("Bye") |> Ethers.send(to: contract_address, from: @from)

      assert {:error, :no_contract_address} = Ethers.deployed_address(tx_hash)

      assert HelloWorldContract.say_hello() |> Ethers.call!(to: contract_address) ==
               ["Bye"]
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
end
