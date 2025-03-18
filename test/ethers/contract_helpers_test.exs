defmodule Ethers.ContractHelpersTest do
  use ExUnit.Case, async: true
  alias Ethers.ContractHelpers

  describe "read_abi" do
    test "works with default abis" do
      assert {abi_results, abi_file} = ContractHelpers.read_abi(abi: :erc20)
      assert is_list(abi_results)
      assert String.ends_with?(abi_file, "priv/abi/erc20.json")
    end

    test "returns error with invalid parameters" do
      assert_raise ArgumentError, fn ->
        ContractHelpers.read_abi(abi: :erc20, abi_file: "file")
      end

      assert_raise ArgumentError, fn ->
        assert {:error, :bad_argument} = ContractHelpers.read_abi(bad_arg: true)
      end
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

  describe "document_types/2" do
    test "returns correct type with name" do
      assert " - amount: `{:uint, 256}`" ==
               ContractHelpers.document_types([{:uint, 256}], ["amount"])
    end

    test "returns correct type if names not provided" do
      assert " - `{:uint, 256}`" == ContractHelpers.document_types([{:uint, 256}])
    end
  end

  describe "generate_arguments" do
    test "works with correct names" do
      assert [{:amount, [], _}, {:sender, [], _}] =
               ContractHelpers.generate_arguments(Ethers.TestModuleName, 2, ["amount", "sender"])
    end

    test "works with invalid names" do
      assert [{:arg1, [], _}, {:arg2, [], _}] =
               ContractHelpers.generate_arguments(Ethers.TestModuleName, 2, ["amount"])
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
end
