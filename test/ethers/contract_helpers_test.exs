defmodule Ethers.ContractHelpersTest do
  use ExUnit.Case
  alias Ethers.ContractHelpers

  describe "read_abi" do
    test "works with default abis" do
      assert {:ok, abi_results} = ContractHelpers.read_abi(abi: :erc20)
      assert is_list(abi_results)
    end

    test "returns error with invalid parameters" do
      assert {:error, :bad_argument} = ContractHelpers.read_abi(abi: :erc20, abi_file: "file")
      assert {:error, :bad_argument} = ContractHelpers.read_abi(bad_arg: true)
    end
  end

  describe "maybe_read_contract_binary" do
    test "returns error with invalid parameters" do
      assert_raise ArgumentError, "Invalid options", fn ->
        ContractHelpers.maybe_read_contract_binary(abi: :erc20, abi_file: "file")
      end

      assert_raise ArgumentError, "Invalid options", fn ->
        ContractHelpers.maybe_read_contract_binary(bad_arg: true)
      end
    end

    test "returns nil if no binary is found" do
      assert is_nil(ContractHelpers.maybe_read_contract_binary(abi: []))
      assert is_nil(ContractHelpers.maybe_read_contract_binary(abi: %{}))
      assert is_nil(ContractHelpers.maybe_read_contract_binary(abi: :erc20))
    end
  end

  describe "generate_arguments" do
    test "works with correct names" do
      assert [{:amount, [], _}, {:sender, [], _}] =
               ContractHelpers.generate_arguments(
                 Ethers.TestModuleName,
                 [{:uint, 256}, :address],
                 ["amount", "sender"]
               )
    end

    test "works with invalid names" do
      assert [{:arg1, [], _}, {:arg2, [], _}] =
               ContractHelpers.generate_arguments(
                 Ethers.TestModuleName,
                 [{:uint, 256}, :address],
                 ["amount"]
               )
    end
  end

  describe "human_signature" do
    test "returns the human signature of a given function" do
      assert "name(uint256 id, address address)" ==
               ContractHelpers.human_signature(%ABI.FunctionSelector{
                 function: "name",
                 input_names: ["id", "address"],
                 types: [{:uint, 256}, :address]
               })
    end

    test "returns human signature with invalid names length" do
      assert "name(uint256, address)" ==
               ContractHelpers.human_signature(%ABI.FunctionSelector{
                 function: "name",
                 input_names: ["id"],
                 types: [{:uint, 256}, :address]
               })

      assert "name(uint256, address)" ==
               ContractHelpers.human_signature(%ABI.FunctionSelector{
                 function: "name",
                 input_names: [],
                 types: [{:uint, 256}, :address]
               })

      assert "name(uint256, address)" ==
               ContractHelpers.human_signature(%ABI.FunctionSelector{
                 function: "name",
                 input_names: nil,
                 types: [{:uint, 256}, :address]
               })
    end
  end

  describe "get_default_action" do
    test "returns correct default actions" do
      assert :call ==
               ContractHelpers.get_default_action(%ABI.FunctionSelector{state_mutability: :view})

      assert :call ==
               ContractHelpers.get_default_action(%ABI.FunctionSelector{state_mutability: :pure})

      assert :send ==
               ContractHelpers.get_default_action(%ABI.FunctionSelector{
                 state_mutability: :payable
               })

      assert :send ==
               ContractHelpers.get_default_action(%ABI.FunctionSelector{
                 state_mutability: :non_payable
               })
    end

    test "raises error for invalid state mutability" do
      assert_raise ArgumentError, "Invalid function state mutability: :invalid", fn ->
        ContractHelpers.get_default_action(%ABI.FunctionSelector{
          state_mutability: :invalid
        })
      end
    end
  end

  describe "maybe_add_to_address" do
    test "adds to address if contract has default address" do
      assert %{to: "0x"} == ContractHelpers.maybe_add_to_address(%{}, Ethers.WithDefaultAddress)
    end

    test "does not add to address if contract doesn't have a default one" do
      assert %{} == ContractHelpers.maybe_add_to_address(%{}, Ethers.WithoutDefaultAddress)
    end
  end
end

defmodule Ethers.WithDefaultAddress do
  def default_address, do: "0x"
end

defmodule Ethers.WithoutDefaultAddress do
  def default_address, do: nil
end
