defmodule Ethers.Contract.Test.PayEtherContract do
  @moduledoc false
  use Ethers.Contract, abi_file: "tmp/pay_ether_abi.json"
end

defmodule Ethers.PayEtherContractTest do
  use ExUnit.Case

  import Ethers.TestHelpers

  alias Ethers.Contract.Test.PayEtherContract

  @from "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266"

  setup :deploy_pay_ether_contract

  describe "pay functions" do
    test "can pay payable functions", %{address: address} do
      assert {:ok, tx_hash} =
               PayEtherContract.pay_me()
               |> Ethers.send_transaction(
                 to: address,
                 value: Ethers.Utils.to_wei(1),
                 from: @from,
                 signer: Ethers.Signer.JsonRPC
               )

      wait_for_transaction!(tx_hash)

      assert {:error, %{"code" => 3}} =
               PayEtherContract.dont_pay_me()
               |> Ethers.send_transaction(
                 to: address,
                 value: Ethers.Utils.to_wei(1),
                 from: @from,
                 signer: Ethers.Signer.JsonRPC
               )
    end
  end

  def deploy_pay_ether_contract(_ctx) do
    address =
      deploy(PayEtherContract, encoded_constructor: PayEtherContract.constructor(), from: @from)

    [address: address]
  end
end
