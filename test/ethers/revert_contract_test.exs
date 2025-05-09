defmodule Ethers.RevertContractTest do
  use ExUnit.Case

  import Ethers.TestHelpers

  alias Ethers.Contract.Test.RevertContract
  alias Ethers.ExecutionError

  @from "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266"

  setup_all :deploy_revert_contract

  describe "using require" do
    test "will cause a revert including revert message", %{address: address} do
      assert {:ok, true} = RevertContract.get(true) |> Ethers.call(to: address, from: @from)

      assert {:error, %{"message" => message}} =
               RevertContract.get(false) |> Ethers.call(to: address, from: @from)

      assert message =~ "success must be true"

      assert_raise Ethers.ExecutionError,
                   ~r/execution reverted: (?:revert: )?success must be true/,
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
    address =
      deploy(RevertContract, encoded_constructor: RevertContract.constructor(), from: @from)

    [address: address]
  end
end
