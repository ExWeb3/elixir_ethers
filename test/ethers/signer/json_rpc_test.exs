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
        from: "0x90F8bf6A479f320ead074411a4B0e7944Ea8c9C1",
        to: "0xFFcf8FDEE72ac11b5c542428B35EEF5769C409f0",
        value: "0x0",
        data: "0x06fdde03",
        gas_price: "0x10e7467522",
        max_fee_per_gas: "0x1448BAF2F5",
        max_priority_fee_per_gas: "0x0"
      }

      assert {:ok,
              "0x02f86f820539820b6680851448baf2f5825a8294ffcf8fdee72ac11b5c542428b35eef5769c409f0808406fdde03c001a064b0b82fe12d59f11993ea978ef8595a4e21e1c2bb811b083ccb6eed230059fca025e4f674692eb3bbd57505d35a328855d4de4abef31fe26ab2e8eb543cfea285"} ==
               Signer.JsonRPC.sign_transaction(transaction, [])
    end

    test "fails signing transaction without from address" do
      transaction = %Ethers.Transaction{
        type: :eip1559,
        chain_id: "0x539",
        nonce: "0xb66",
        gas: "0x5A82",
        from: nil,
        to: "0xFFcf8FDEE72ac11b5c542428B35EEF5769C409f0",
        value: "0x0",
        data: "0x06fdde03",
        gas_price: "0x10e7467522",
        max_fee_per_gas: "0x1448BAF2F5",
        max_priority_fee_per_gas: "0x0"
      }

      assert {:error, error} =
               Signer.JsonRPC.sign_transaction(transaction, [])

      assert error["message"] =~ "from not found"
    end
  end

  describe "accounts/1" do
    test "returns account list" do
      assert {:ok, accounts} = Signer.JsonRPC.accounts([])

      assert accounts == [
               "0x90f8bf6a479f320ead074411a4b0e7944ea8c9c1",
               "0xffcf8fdee72ac11b5c542428b35eef5769c409f0",
               "0x22d491bde2303f2f43325b2108d26f1eaba1e32b",
               "0xe11ba2b4d45eaed5996cd0823791e0c93114882d",
               "0xd03ea8624c8c5987235048901fb614fdca89b117",
               "0x95ced938f7991cd0dfcb48f0a06a40fa1af46ebc",
               "0x3e5e9111ae8eb78fe1cc3bb8915d5d461f3ef9a9",
               "0x28a8746e75304c0780e011bed21c72cd78cd535e",
               "0xaca94ef8bd5ffee41947b4585a84bda5a3d3da6e",
               "0x1df62f291b2e969fb0849d99d9ce41e2f137006e"
             ]
    end
  end
end
