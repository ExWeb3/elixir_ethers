defmodule EthersTest do
  use ExUnit.Case
  doctest Ethers

  describe "current_gas_price" do
    test "returns the correct gas price" do
      assert {:ok, 2_000_000_000} = Ethers.current_gas_price()
    end
  end
end
