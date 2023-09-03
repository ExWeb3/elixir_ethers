defmodule EthersTest do
  use ExUnit.Case
  doctest Ethers

  describe "current_gas_price" do
    test "returns the correct gas price" do
      assert {:ok, 2_000_000_000} = Ethers.current_gas_price()
    end
  end

  describe "current_block_number" do
    test "returns the current block number" do
      assert {:ok, n} = Ethers.current_block_number()
      assert n > 0
    end

    test "can override the rpc options" do
      assert {:ok, 1001} ==
               Ethers.current_block_number(
                 rpc_client: Ethers.TestRPCModule,
                 rpc_opts: [block: "0x3E9"]
               )
    end
  end
end
