defmodule Ethers.TxDataTest do
  use ExUnit.Case

  alias Ethers.TxData

  @function_selector %ABI.FunctionSelector{
    function: "get",
    method_id: <<109, 76, 230, 60>>,
    type: :function,
    inputs_indexed: nil,
    state_mutability: :view,
    input_names: [],
    types: [],
    returns: [uint: 256],
    return_names: ["amount"]
  }

  describe "to_map/2" do
    test "converts a TxData to transaction map" do
      tx_data = TxData.new("0xffff", @function_selector, nil, nil)

      assert %{data: "0xffff"} == TxData.to_map(tx_data, [])
    end

    test "includes the default address if any" do
      tx_data = TxData.new("0xffff", @function_selector, "0xdefault", nil)

      assert %{data: "0xffff", to: "0xdefault"} == TxData.to_map(tx_data, [])
    end

    test "includes overrides in transaction map" do
      tx_data = TxData.new("0xffff", @function_selector, "0xdefault", nil)

      assert %{data: "0xffff", to: "0xdefault", from: "0xfrom"} ==
               TxData.to_map(tx_data, from: "0xfrom")
    end

    test "can override default address" do
      tx_data = TxData.new("0xffff", @function_selector, "0xdefault", nil)

      assert %{data: "0xffff", to: "0xnotdefault"} ==
               TxData.to_map(tx_data, to: "0xnotdefault")
    end

    test "integer overrides are converted to hex" do
      tx_data = TxData.new("0xffff", @function_selector, nil, nil)

      assert %{data: "0xffff", gas: "0x1"} ==
               TxData.to_map(tx_data, gas: 1)
    end
  end
end
