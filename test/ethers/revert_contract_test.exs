defmodule Ethers.RevertContractTest do
  use ExUnit.Case

  alias Ethers.Contract.Test.RevertContract
  alias Ethers.ExecutionError

  @from "0x90f8bf6a479f320ead074411a4b0e7944ea8c9c1"

  setup :deploy_revert_contract

  describe "using require" do
    test "will cause a revert including revert message", %{address: address} do
      assert {:ok, true} = RevertContract.get(true) |> Ethers.call(to: address, from: @from)

      assert {:error, %{"message" => message}} =
               RevertContract.get(false) |> Ethers.call(to: address, from: @from)

      assert message =~ "success must be true"

      assert_raise Ethers.ExecutionError,
                   "VM Exception while processing transaction: revert success must be true",
                   fn ->
                     RevertContract.get(false) |> Ethers.call!(to: address, from: @from)
                   end
    end
  end

  describe "using revert" do
    test "will cause a revert including revert message", %{address: address} do
      assert {:error, %{"message" => message}} =
               RevertContract.reverting() |> Ethers.call(to: address, from: @from)

      assert message =~ "revert message"
    end
  end

  describe "using revert with error" do
    test "will cause a revert including revert message", %{address: address} do
      assert {:error, %RevertContract.Errors.RevertWithMessage{message: message}} =
               RevertContract.reverting_with_message()
               |> Ethers.call(to: address, from: @from)

      assert message =~ "this is sad!"
    end

    test "will raise an exception", %{address: address} do
      assert_raise ExecutionError,
                   ~s'#Ethers.Error<error RevertWithMessage(string message "this is sad!")>',
                   fn ->
                     RevertContract.reverting_with_message()
                     |> Ethers.call!(to: address, from: @from)
                   end
    end
  end

  defp deploy_revert_contract(_ctx) do
    encoded_constructor = RevertContract.constructor()

    assert {:ok, tx_hash} =
             Ethers.deploy(RevertContract,
               encoded_constructor: encoded_constructor,
               from: @from
             )

    assert {:ok, address} = Ethers.deployed_address(tx_hash)

    [address: address]
  end
end
