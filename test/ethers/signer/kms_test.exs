defmodule Ethers.Signer.KMSTest do
  use ExUnit.Case
  use Mimic

  alias Ethers.Signer
  alias Ethers.SignerFixtures

  describe "sign_transaction/2" do
    test "signs the transaction with the correct data" do
      expect(ExAws, :request, fn _ ->
        SignerFixtures.kms_public_key_response()
      end)

      expect(ExAws, :request, fn _ ->
        SignerFixtures.kms_sign_response()
      end)

      transaction = %Ethers.Transaction{
        type: :eip1559,
        chain_id: "0x539",
        nonce: "0xb66",
        gas: "0x5A82",
        from: "0x4eed49289Ac2876C9c966FC16b22F6eC5bf0817c",
        to: "0xFFcf8FDEE72ac11b5c542428B35EEF5769C409f0",
        value: "0x0",
        data: "0x06fdde03",
        gas_price: "0x10e7467522",
        max_fee_per_gas: "0x1448BAF2F5",
        max_priority_fee_per_gas: "0x0"
      }

      assert {:ok,
              "0x02f86f820539820b6680851448baf2f5825a8294ffcf8fdee72ac11b5c542428b35eef5769c409f0808406fdde03c001a032ba3398b3223445b858849e275d6dbb1a6708f305bb2b8c427143f9239bb9bea053fa0a993614ed279496088147827086767088e33a587e3c18b5978f8ac018e5"} ==
               Signer.KMS.sign_transaction(transaction,
                 kms_key_id: "ddb1aedd-77d1-4b90-a3a8-d77fb82ba533"
               )
    end

    test "fails if no kms key id is given" do
      transaction = %Ethers.Transaction{
        type: :eip1559,
        chain_id: "0x539",
        nonce: "0xb66",
        gas: "0x5A82",
        from: "0x4eed49289Ac2876C9c966FC16b22F6eC5bf0817c",
        to: "0xFFcf8FDEE72ac11b5c542428B35EEF5769C409f0",
        value: "0x0",
        data: "0x06fdde03",
        gas_price: "0x10e7467522",
        max_fee_per_gas: "0x1448BAF2F5",
        max_priority_fee_per_gas: "0x0"
      }

      assert {:error, :kms_key_not_found} ==
               Signer.KMS.sign_transaction(transaction,
                 kms_key_id: nil
               )
    end

    test "fails if no from address is given" do
      expect(ExAws, :request, fn _ ->
        SignerFixtures.kms_public_key_response()
      end)

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

      assert {:error, :no_from_address} ==
               Signer.KMS.sign_transaction(transaction,
                 kms_key_id: "ddb1aedd-77d1-4b90-a3a8-d77fb82ba533"
               )
    end

    test "fails if from address does not match the public key specified in the signer" do
      expect(ExAws, :request, fn _ ->
        SignerFixtures.kms_public_key_response()
      end)

      transaction = %Ethers.Transaction{
        type: :eip1559,
        chain_id: "0x539",
        nonce: "0xb66",
        gas: "0x5A82",
        from: "0xFFcf8FDEE72ac11b5c542428B35EEF5769C409f0",
        to: "0xFFcf8FDEE72ac11b5c542428B35EEF5769C409f0",
        value: "0x0",
        data: "0x06fdde03",
        gas_price: "0x10e7467522",
        max_fee_per_gas: "0x1448BAF2F5",
        max_priority_fee_per_gas: "0x0"
      }

      assert {:error, :wrong_public_key} ==
               Signer.KMS.sign_transaction(transaction,
                 kms_key_id: "ddb1aedd-77d1-4b90-a3a8-d77fb82ba533"
               )
    end
  end
end
