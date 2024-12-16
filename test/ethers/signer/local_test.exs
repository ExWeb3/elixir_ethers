defmodule Ethers.Signer.LocalTest do
  use ExUnit.Case

  alias Ethers.Signer
  alias Ethers.Transaction.Eip1559

  @private_key "0x4f3edf983ac636a65a842ce7c78d9aa706d3b113bce9c46f30d7d21715b23b1d"

  describe "sign_transaction/2" do
    test "signs the transaction with the correct data" do
      transaction = %Eip1559{
        chain_id: 1337,
        nonce: 2918,
        gas: 23_170,
        to: "0xFFcf8FDEE72ac11b5c542428B35EEF5769C409f0",
        value: 0,
        input: "0x06fdde03",
        max_fee_per_gas: 87_119_557_365,
        max_priority_fee_per_gas: 0
      }

      assert {:ok,
              "0x02f86f820539820b6680851448baf2f5825a8294ffcf8fdee72ac11b5c542428b35eef5769c409f0808406fdde03c001a064b0b82fe12d59f11993ea978ef8595a4e21e1c2bb811b083ccb6eed230059fca025e4f674692eb3bbd57505d35a328855d4de4abef31fe26ab2e8eb543cfea285"} ==
               Signer.Local.sign_transaction(transaction, private_key: @private_key)
    end

    # TODO: Add Legacy transaction test
  end

  describe "accounts/1" do
    test "returns the correct address for a given private key as binary" do
      key =
        Ethers.Utils.hex_decode!(
          "0x4f3edf983ac636a65a842ce7c78d9aa706d3b113bce9c46f30d7d21715b23b1d"
        )

      assert {:ok, ["0x90F8bf6A479f320ead074411a4B0e7944Ea8c9C1"]} ==
               Signer.Local.accounts(private_key: key)
    end

    test "returns the correct address for a given private key as hex" do
      assert {:ok, ["0x90F8bf6A479f320ead074411a4B0e7944Ea8c9C1"]} ==
               Signer.Local.accounts(
                 private_key: "0x4f3edf983ac636a65a842ce7c78d9aa706d3b113bce9c46f30d7d21715b23b1d"
               )

      assert {:ok, ["0xACa94ef8bD5ffEE41947b4585a84BdA5a3d3DA6E"]} ==
               Signer.Local.accounts(
                 private_key: "0x829e924fdf021ba3dbbc4225edfece9aca04b929d6e75613329ca6f1d31c0bb4"
               )

      assert {:ok, ["0xACa94ef8bD5ffEE41947b4585a84BdA5a3d3DA6E"]} ==
               Signer.Local.accounts(
                 private_key: "829e924fdf021ba3dbbc4225edfece9aca04b929d6e75613329ca6f1d31c0bb4"
               )
    end

    test "fails if private key is not given" do
      assert {:error, :no_private_key} == Signer.Local.accounts(other_opts: :ignore)
    end

    test "fails if private key is incorrect" do
      assert {:error, :invalid_private_key} == Signer.Local.accounts(private_key: "invalid")
    end
  end
end
