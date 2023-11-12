defmodule Ethers.Contract.Test.PayEtherContract do
  @moduledoc false
  use Ethers.Contract, abi_file: "tmp/pay_ether_abi.json"
end

defmodule Ethers.PayEtherContractTest do
  use ExUnit.Case

  alias Ethers.Contract.Test.PayEtherContract

  @from "0x90f8bf6a479f320ead074411a4b0e7944ea8c9c1"

  setup :deploy_pay_ether_contract

  describe "pay functions" do
    test "can pay payable functions", %{address: address} do
      assert {:ok, _tx_hash} =
               PayEtherContract.pay_me()
               |> Ethers.send(to: address, value: Ethers.Utils.to_wei(1), from: @from)

      assert {:error, %{"code" => -32_000}} =
               PayEtherContract.dont_pay_me()
               |> Ethers.send(to: address, value: Ethers.Utils.to_wei(1), from: @from)
    end
  end

  def deploy_pay_ether_contract(_ctx) do
    encoded_constructor = PayEtherContract.constructor()

    assert {:ok, tx_hash} =
             Ethers.deploy(PayEtherContract,
               encoded_constructor: encoded_constructor,
               from: @from
             )

    assert {:ok, address} = Ethers.deployed_address(tx_hash)

    [address: address]
  end
end
