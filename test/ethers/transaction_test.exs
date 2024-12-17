defmodule Ethers.TransactionTest do
  use ExUnit.Case

  alias Ethers.Transaction

  describe "encode/1" do
    test "encodes transaction with address having leading zeros" do
      transaction = %Ethers.Transaction.Eip1559{
        chain_id: 1337,
        gas: 4660,
        input: "0x0006fdde03",
        max_fee_per_gas: 87_119_557_365,
        max_priority_fee_per_gas: 0,
        nonce: 1,
        to: "0x00008FDEE72ac11b5c542428B35EEF5769C409f0",
        value: 0
      }

      assert "0x02eb8205390180851448baf2f58212349400008fdee72ac11b5c542428b35eef5769c409f080850006fdde03c0" ==
               Transaction.encode(transaction) |> Ethers.Utils.hex_encode()
    end

    test "encodes transaction with empty data" do
      transaction = %Ethers.Transaction.Eip1559{
        chain_id: 1337,
        gas: 4660,
        input: "",
        max_fee_per_gas: 87_119_557_365,
        max_priority_fee_per_gas: 0,
        nonce: 1,
        to: "0x00008FDEE72ac11b5c542428B35EEF5769C409f0",
        value: 0
      }

      assert "0x02e68205390180851448baf2f58212349400008fdee72ac11b5c542428b35eef5769c409f08080c0" ==
               Transaction.encode(transaction) |> Ethers.Utils.hex_encode()
    end
  end

  describe "decode/1" do
    test "decodes raw EIP-1559 transaction correctly" do
      raw_tx =
        "0x02f8af0177837a12008502c4bfbc3282f88c948881562783028f5c1bcb985d2283d5e170d8888880b844a9059cbb0000000000000000000000002ef7f5c7c727d8845e685f462a5b4f8ac4972a6700000000000000000000000000000000000000000000051ab2ea6fbbb7420000c001a007280557e86f690290f9ea9e26cc17e0cf09a17f6c2d041e95b33be4b81888d0a06c7a24e8fba5cceb455b19950849b9733f0deb92d7e8c2a919f4a82df9c6036a"

      expected_from = "0xCD543881D298BB4dd626b273200ed61867fB395D"
      expected_hash = "0x224d121387e3bbabfc7bad271b22dddc0dc2743aaf49d850161f628ac9514179"

      assert {:ok, decoded_tx} = Transaction.decode(raw_tx)
      assert %Transaction.Signed{transaction: %Transaction.Eip1559{}} = decoded_tx

      # Verify transaction hash matches
      assert Transaction.transaction_hash(decoded_tx) == expected_hash

      # Verify recovered from address
      recovered_from = Transaction.Signed.from_address(decoded_tx)
      assert String.downcase(recovered_from) == String.downcase(expected_from)

      # Verify other transaction fields
      assert decoded_tx.transaction.chain_id == 1
      assert decoded_tx.transaction.gas == 63_628
      assert decoded_tx.transaction.max_fee_per_gas == 11_890_834_482
      assert decoded_tx.transaction.nonce == 119
      assert decoded_tx.transaction.max_priority_fee_per_gas == 8_000_000
      assert decoded_tx.transaction.to == "0x8881562783028f5c1bcb985d2283d5e170d88888"
      assert decoded_tx.transaction.value == 0
    end

    test "decodes raw legacy transaction correctly" do
      raw_tx =
        "0xf86c81c6850c92a69c0082520894e48c9a989438606a79a7560cfba3d34bafbac38e87596f744abf34368025a0ee0b54a64cf8130e36cd1d19395d6d434c285c832a7908873a24610ec32896dfa070b5e779cdcaf5c661c1df44e80895f6ab68463d3ede2cf4955855bc3c6edebb"

      expected_from = "0xB24D14a32CF2fC733209525235937736fC81C1dB"
      expected_hash = "0x5a456fc4bb92a075552d1b8b2ce0e61c75b87a237a8108819ea735d13b7d52aa"

      assert {:ok, decoded_tx} = Transaction.decode(raw_tx)
      assert %Transaction.Signed{transaction: %Transaction.Legacy{}} = decoded_tx

      # Verify transaction hash matches
      assert Transaction.transaction_hash(decoded_tx) == expected_hash

      # Verify recovered from address
      recovered_from = Transaction.Signed.from_address(decoded_tx)
      assert String.downcase(recovered_from) == String.downcase(expected_from)

      # Verify other transaction fields
      assert decoded_tx.transaction.chain_id == 1
      assert decoded_tx.transaction.gas == 21_000
      assert decoded_tx.transaction.nonce == 198
      assert decoded_tx.transaction.gas_price == 54_000_000_000
      assert decoded_tx.transaction.to == "0xe48c9a989438606a79a7560cfba3d34bafbac38e"
      assert decoded_tx.transaction.value == 25_173_818_188_182_582
    end
  end
end
