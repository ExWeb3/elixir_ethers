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

  describe "inspecting function calls" do
    test "renders the correct values when inspected" do
      assert "#Ethers.TxData<function get() view returns (uint256)>" ==
               inspect(CounterContract.get())

      assert "#Ethers.TxData<function set(uint256 newAmount 101) non_payable>" ==
               inspect(CounterContract.set(101))
    end

    test "shows unknown state mutability correctly" do
      tx_data = CounterContract.get()

      assert "#Ethers.TxData<function get() unknown returns (uint256)>" ==
               inspect(put_in(tx_data.selector.state_mutability, nil))
    end

    test "skips argument names in case of length mismatch" do
      tx_data = CounterContract.set(101)

      assert "#Ethers.TxData<function set(uint256 101) non_payable>" ==
               inspect(put_in(tx_data.selector.input_names, ["invalid", "names", "length"]))
    end

    test "includes default address if given" do
      tx_data = CounterContract.get()

      tx_data_with_default_address = %{tx_data | default_address: @from}

      assert "#Ethers.TxData<function get() view returns (uint256)\n  default_address: \"0x90F8bf6A479f320ead074411a4B0e7944Ea8c9C1\">" ==
               inspect(tx_data_with_default_address)
    end
  end

  describe "calling functions" do
    setup :deploy_counter_contract

    test "calling view functions", %{address: address} do
      assert %Ethers.TxData{
               data: "0x6d4ce63c",
               selector: %ABI.FunctionSelector{
                 function: "get",
                 method_id: <<109, 76, 230, 60>>,
                 type: :function,
                 inputs_indexed: nil,
                 state_mutability: :view,
                 input_names: [],
                 types: [],
                 returns: [uint: 256]
               },
               default_address: nil
             } == CounterContract.get()

      assert {:ok, [100]} = CounterContract.get() |> Ethers.call(to: address)
      assert [100] = CounterContract.get() |> Ethers.call!(to: address)
    end

    test "sending transaction with state mutating functions", %{address: address} do
      {:ok, _tx_hash} = CounterContract.set(101) |> Ethers.send(from: @from, to: address)

      {:ok, [101]} = CounterContract.get() |> Ethers.call(to: address)
    end

    test "sending transaction with state mutating functions using bang functions", %{
      address: address
    } do
      _tx_hash = CounterContract.set(101) |> Ethers.send!(from: @from, to: address)

      [101] = CounterContract.get() |> Ethers.call!(to: address)
    end

    test "returns error if to address is not given" do
      assert {:error, :no_to_address} = CounterContract.get() |> Ethers.call()
      assert {:error, :no_to_address} = CounterContract.set(101) |> Ethers.send(from: @from)

      assert {:error, :no_to_address} =
               CounterContract.set(101) |> Ethers.send(from: @from, gas: 100)

      assert {:error, :no_to_address} = CounterContract.set(101) |> Ethers.send()

      assert {:error, :no_to_address} =
               CounterContract.set(101) |> Ethers.estimate_gas(from: @from, gas: 100)
    end

    test "raises if to address is not given using the bang functions" do
      assert_raise Ethers.ExecutionError, "Unexpected error: no_to_address", fn ->
        CounterContract.get() |> Ethers.call!()
      end

      assert_raise Ethers.ExecutionError, "Unexpected error: no_to_address", fn ->
        CounterContract.set(101) |> Ethers.send!(from: @from)
      end

      assert_raise Ethers.ExecutionError, "Unexpected error: no_to_address", fn ->
        CounterContract.set(101) |> Ethers.send!(from: @from, gas: 100)
      end

      assert_raise Ethers.ExecutionError, "Unexpected error: no_to_address", fn ->
        CounterContract.set(101) |> Ethers.estimate_gas!(from: @from, gas: 100)
      end
    end

    test "returns the gas estimate with Ethers.estimate_gas", %{address: address} do
      assert {:ok, gas_estimate} =
               CounterContract.set(101) |> Ethers.estimate_gas(from: @from, to: address)

      assert is_integer(gas_estimate)

      # Same with the bang function
      assert ^gas_estimate =
               CounterContract.set(101) |> Ethers.estimate_gas!(from: @from, to: address)
    end

    test "returns the params when called" do
      assert %Ethers.TxData{
               data: "0x60fe47b10000000000000000000000000000000000000000000000000000000000000065",
               selector: %ABI.FunctionSelector{
                 function: "set",
                 method_id: <<96, 254, 71, 177>>,
                 type: :function,
                 inputs_indexed: nil,
                 state_mutability: :non_payable,
                 input_names: ["newAmount"],
                 types: [uint: 256],
                 returns: []
               },
               default_address: nil
             } == CounterContract.set(101)
    end
  end

  describe "Event filter works with get_logs" do
    setup :deploy_counter_contract

    test "can get the emitted event with the correct filter", %{address: address} do
      {:ok, _tx_hash} = CounterContract.set(101) |> Ethers.send(from: @from, to: address)

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

    test "cat get the emitted events with get_logs! function", %{address: address} do
      {:ok, tx_hash} = CounterContract.set(101) |> Ethers.send(from: @from, to: address)

      assert filter = CounterContract.EventFilters.set_called(nil)

      assert [
               %Ethers.Event{
                 address: ^address,
                 topics: ["SetCalled(uint256,uint256)", 100],
                 data: [101],
                 data_raw: "0x0000000000000000000000000000000000000000000000000000000000000065",
                 log_index: 0,
                 removed: false,
                 topics_raw: [
                   "0x9db4e91e99652c2cf1713076f100fca6a4f5b81f166bce406ff2b3012694f49f",
                   "0x0000000000000000000000000000000000000000000000000000000000000064"
                 ],
                 transaction_hash: ^tx_hash,
                 transaction_index: 0,
                 block_hash: block_hash,
                 block_number: block_number
               }
             ] = Ethers.get_logs!(filter)

      assert is_integer(block_number)
      assert String.valid?(block_hash)
    end

    test "can filter logs with fromBlock and toBlock options", %{address: address} do
      {:ok, _tx_hash} = CounterContract.set(101) |> Ethers.send(from: @from, to: address)

      assert filter = CounterContract.EventFilters.set_called(nil)

      {:ok, current_block_number} = Ethers.current_block_number()

      assert [] ==
               Ethers.get_logs!(filter,
                 fromBlock: current_block_number - 1,
                 toBlock: current_block_number - 1
               )
    end
  end

  describe "override block number" do
    setup :deploy_counter_contract

    test "can call a view function on a previous block", %{address: address} do
      {:ok, _tx_hash} = CounterContract.set(101) |> Ethers.send(from: @from, to: address)
      {:ok, block_1} = Ethereumex.HttpClient.eth_block_number()

      {:ok, _tx_hash} = CounterContract.set(102) |> Ethers.send(from: @from, to: address)
      {:ok, block_2} = Ethers.current_block_number()

      assert is_integer(block_2)

      {:ok, _tx_hash} = CounterContract.set(103) |> Ethers.send(from: @from, to: address)

      assert CounterContract.get() |> Ethers.call!(to: address, block: "latest") == [103]
      assert CounterContract.get() |> Ethers.call!(to: address, block: block_2) == [102]
      assert CounterContract.get() |> Ethers.call!(to: address, block: block_1) == [101]
    end
  end

  defp deploy_counter_contract(_ctx) do
    init_params = CounterContract.constructor(100)
    assert {:ok, tx_hash} = Ethers.deploy(CounterContract, init_params, %{from: @from})
    assert {:ok, address} = Ethers.deployed_address(tx_hash)

    [address: address]
  end
end
