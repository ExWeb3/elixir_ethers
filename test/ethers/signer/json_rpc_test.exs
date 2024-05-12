defmodule Ethers.Signer.JsonRPCTest do
  use ExUnit.Case

  alias Ethers.Signer

  describe "sign_transaction/2" do
    test "signs the transaction with the correct data" do
      transaction = %Ethers.Transaction{
        type: :eip1559,
        chain_id: "0x539",
        nonce: "0xb66",
        gas: "0x5A82",
        from: "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
        to: "0xFFcf8FDEE72ac11b5c542428B35EEF5769C409f0",
        value: "0x0",
        data: "0x06fdde03",
        gas_price: "0x10e7467522",
        max_fee_per_gas: "0x1448BAF2F5",
        max_priority_fee_per_gas: "0x0"
      }

      assert {:ok,
              "0x02f871827a69820b6680851448baf2f5825a8294ffcf8fdee72ac11b5c542428b35eef5769c409f0808406fdde03c082f4f5a03d39a64cec141391314296113f494c750619792b845966975d5f9862307edd83a06027e4f44dceae37b773933587e68e5b3174cd490ba0e2f0628dc33eb5f53f97"} ==
               Signer.JsonRPC.sign_transaction(transaction, [])
    end

    test "fails signing transaction with wrong from address" do
      transaction = %Ethers.Transaction{
        type: :eip1559,
        chain_id: "0x539",
        nonce: "0xb66",
        gas: "0x5A82",
        from: "0xbba94ef8bd5ffee41947b4585a84bda5a3d3da6e",
        to: "0xFFcf8FDEE72ac11b5c542428B35EEF5769C409f0",
        value: "0x0",
        data: "0x06fdde03",
        gas_price: "0x10e7467522",
        max_fee_per_gas: "0x1448BAF2F5",
        max_priority_fee_per_gas: "0x0"
      }

      assert {:error, error} =
               Signer.JsonRPC.sign_transaction(transaction, [])

      assert error["message"] =~ "No Signer available"
    end
  end

  describe "accounts/1" do
    test "returns account list" do
      assert {:ok, accounts} = Signer.JsonRPC.accounts([])

      assert accounts == [
               "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266",
               "0x70997970c51812dc3a010c7d01b50e0d17dc79c8",
               "0x3c44cdddb6a900fa2b585dd299e03d12fa4293bc",
               "0x90f79bf6eb2c4f870365e785982e1f101e93b906",
               "0x15d34aaf54267db7d7c367839aaf71a00a2c6a65",
               "0x9965507d1a55bcc2695c58ba16fb37d819b0a4dc",
               "0x976ea74026e726554db657fa54763abd0c3a0aa9",
               "0x14dc79964da2c08b23698b3d3cc7ca32193d9955",
               "0x23618e81e3f5cdf7f54c3d65f7fbc0abf5b21e8f",
               "0xa0ee7a142d267c1f36714e4a8f75612f20a79720"
             ]
    end
  end
end
