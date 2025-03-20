defmodule Ethers.TransactionTest do
  use ExUnit.Case, async: true

  alias Ethers.Transaction
  alias Ethers.Utils

  describe "encode/1" do
    test "encodes transaction with address having leading zeros" do
      transaction = %Ethers.Transaction.Eip1559{
        chain_id: 1337,
        gas: 4660,
        input: Utils.hex_decode!("0x0006fdde03"),
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

    test "encodes a transaction with a blob" do
      transaction = %Ethers.Transaction.Eip4844{
        blob_versioned_hashes: [
          Utils.hex_decode!("0x01bb9dc6ee48ae6a6f7ffd69a75196a4d49723beedf35981106e8da0efd8f796")
        ],
        chain_id: 1,
        gas: 5_000_000,
        input:
          Utils.hex_decode!(
            "0x0c8f4a10000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000001a00000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000633b68f5d8d3a86593ebb815b4663bcbe0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000116680000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000000"
          ),
        max_fee_per_blob_gas: 5_372_124_052,
        max_fee_per_gas: 42_499_154_466,
        max_priority_fee_per_gas: 3_000_000_000,
        nonce: 625_972,
        to: "0x68d30f47F19c07bCCEf4Ac7FAE2Dc12FCa3e0dC9",
        value: 0
      }

      assert "0x03f9025a0183098d3484b2d05e008509e525a222834c4b409468d30f47f19c07bccef4ac7fae2dc12fca3e0dc980b902040c8f4a10000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000001a00000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000633b68f5d8d3a86593ebb815b4663bcbe0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000116680000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000000c0850140341b94e1a001bb9dc6ee48ae6a6f7ffd69a75196a4d49723beedf35981106e8da0efd8f796" ==
               Transaction.encode(transaction) |> Ethers.Utils.hex_encode()
    end
  end

  describe "decode/1" do
    test "decodes raw EIP-4844 transaction and re-encodes it correctly" do
      raw_tx =
        "0x03f9043c01830b3444847d2b75008519a4418ab283036fd5941c479675ad559dc151f6ec7ed3fbf8cee79582b680b8a43e5aa08200000000000000000000000000000000000000000000000000000000000bfc5200000000000000000000000000000000000000000000000000000000001bd614000000000000000000000000e64a54e2533fd126c2e452c5fab544d80e2e4eb500000000000000000000000000000000000000000000000000000000101868220000000000000000000000000000000000000000000000000000000010186a47f902c0f8dd941c479675ad559dc151f6ec7ed3fbf8cee79582b6f8c6a00000000000000000000000000000000000000000000000000000000000000000a00000000000000000000000000000000000000000000000000000000000000001a0000000000000000000000000000000000000000000000000000000000000000aa0b53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103a0360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbca0a10aa54071443520884ed767b0684edf43acec528b7da83ab38ce60126562660f90141948315177ab297ba92a06054ce80a67ed4dbd7ed3af90129a00000000000000000000000000000000000000000000000000000000000000006a00000000000000000000000000000000000000000000000000000000000000007a00000000000000000000000000000000000000000000000000000000000000009a0000000000000000000000000000000000000000000000000000000000000000aa0b53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103a0360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbca0a66cc928b5edb82af9bd49922954155ab7b0942694bea4ce44661d9a8742c2d9a0a66cc928b5edb82af9bd49922954155ab7b0942694bea4ce44661d9a8742c2daa0f652222313e28459528d920b65115c16c04f3efc82aaedc97be59f3f3797e352f89b94e64a54e2533fd126c2e452c5fab544d80e2e4eb5f884a00000000000000000000000000000000000000000000000000000000000000004a00000000000000000000000000000000000000000000000000000000000000005a0e85fd79f89ff278fc57d40aecb7947873df9f0beac531c8f71a98f630e1eab62a07686888b19bb7b75e46bb1aa328b65150743f4899443d722f0adf8e252ccda410af863a001e74519daf1b03d40e76d557588db2e9b21396f7aeb6086bd794cc4357083efa00169766b1aff3508331a39e7081e591a3ff3bacf957788571269797db7ff3ccca0017045639ffe91febe66cc4427fcf6331980dd9a0dab4af3e81c5514b918ed6180a036a73bf3fe4b9a375c2564b2b1a4a795c82b3923225af0a2ab5d7a561b0c4b92a0366ac3b831ece20f95d1eac369b1c8d4c2c5ac730655d89c005fe310d1db2086"

      expected_from = "0xC1b634853Cb333D3aD8663715b08f41A3Aec47cc"
      expected_hash = "0x2a7522ff8773f484123ff169d5a42b4d917d3da5af65baae71f32ab7aeb3dc29"

      assert {:ok, decoded_tx} = Transaction.decode(raw_tx)
      assert %Transaction.Signed{payload: %Transaction.Eip4844{}} = decoded_tx

      # Verify transaction hash matches
      assert Transaction.transaction_hash(decoded_tx) == expected_hash

      # Verify recovered from address
      recovered_from = Transaction.Signed.from_address(decoded_tx)
      assert String.downcase(recovered_from) == String.downcase(expected_from)

      # Verify other transaction fields
      assert decoded_tx.payload.chain_id == 1
      assert decoded_tx.payload.gas == 225_237
      assert decoded_tx.payload.max_fee_per_gas == 110_129_941_170
      assert decoded_tx.payload.nonce == 734_276
      assert decoded_tx.payload.max_priority_fee_per_gas == 2_100_000_000
      assert decoded_tx.payload.to == "0x1c479675ad559DC151F6Ec7ed3FbF8ceE79582B6"
      assert decoded_tx.payload.value == 0
      assert decoded_tx.payload.max_fee_per_blob_gas == 10

      # Verify access list
      access_list =
        Enum.map(decoded_tx.payload.access_list, fn [address, storage_keys] ->
          %{
            "address" => Utils.hex_encode(address),
            "storageKeys" => Enum.map(storage_keys, &Utils.hex_encode(&1, :address))
          }
        end)

      assert access_list ==
               [
                 %{
                   "address" => "0x1c479675ad559dc151f6ec7ed3fbf8cee79582b6",
                   "storageKeys" => [
                     "0x0000000000000000000000000000000000000000000000000000000000000000",
                     "0x0000000000000000000000000000000000000000000000000000000000000001",
                     "0x000000000000000000000000000000000000000000000000000000000000000a",
                     "0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103",
                     "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc",
                     "0xa10aa54071443520884ed767b0684edf43acec528b7da83ab38ce60126562660"
                   ]
                 },
                 %{
                   "address" => "0x8315177ab297ba92a06054ce80a67ed4dbd7ed3a",
                   "storageKeys" => [
                     "0x0000000000000000000000000000000000000000000000000000000000000006",
                     "0x0000000000000000000000000000000000000000000000000000000000000007",
                     "0x0000000000000000000000000000000000000000000000000000000000000009",
                     "0x000000000000000000000000000000000000000000000000000000000000000a",
                     "0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103",
                     "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc",
                     "0xa66cc928b5edb82af9bd49922954155ab7b0942694bea4ce44661d9a8742c2d9",
                     "0xa66cc928b5edb82af9bd49922954155ab7b0942694bea4ce44661d9a8742c2da",
                     "0xf652222313e28459528d920b65115c16c04f3efc82aaedc97be59f3f3797e352"
                   ]
                 },
                 %{
                   "address" => "0xe64a54e2533fd126c2e452c5fab544d80e2e4eb5",
                   "storageKeys" => [
                     "0x0000000000000000000000000000000000000000000000000000000000000004",
                     "0x0000000000000000000000000000000000000000000000000000000000000005",
                     "0xe85fd79f89ff278fc57d40aecb7947873df9f0beac531c8f71a98f630e1eab62",
                     "0x7686888b19bb7b75e46bb1aa328b65150743f4899443d722f0adf8e252ccda41"
                   ]
                 }
               ]

      # Verify blob versioned hashes
      blob_versioned_hashes =
        Enum.map(decoded_tx.payload.blob_versioned_hashes, &Utils.hex_encode(&1))

      assert blob_versioned_hashes == [
               "0x01e74519daf1b03d40e76d557588db2e9b21396f7aeb6086bd794cc4357083ef",
               "0x0169766b1aff3508331a39e7081e591a3ff3bacf957788571269797db7ff3ccc",
               "0x017045639ffe91febe66cc4427fcf6331980dd9a0dab4af3e81c5514b918ed61"
             ]

      assert Ethers.Utils.hex_encode(Transaction.encode(decoded_tx)) == raw_tx
    end

    test "decodes raw EIP-1559 transaction and re-encodes it correctly" do
      raw_tx =
        "0x02f8af0177837a12008502c4bfbc3282f88c948881562783028f5c1bcb985d2283d5e170d8888880b844a9059cbb0000000000000000000000002ef7f5c7c727d8845e685f462a5b4f8ac4972a6700000000000000000000000000000000000000000000051ab2ea6fbbb7420000c001a007280557e86f690290f9ea9e26cc17e0cf09a17f6c2d041e95b33be4b81888d0a06c7a24e8fba5cceb455b19950849b9733f0deb92d7e8c2a919f4a82df9c6036a"

      expected_from = "0xCD543881D298BB4dd626b273200ed61867fB395D"
      expected_hash = "0x224d121387e3bbabfc7bad271b22dddc0dc2743aaf49d850161f628ac9514179"

      assert {:ok, decoded_tx} = Transaction.decode(raw_tx)
      assert %Transaction.Signed{payload: %Transaction.Eip1559{}} = decoded_tx

      # Verify transaction hash matches
      assert Transaction.transaction_hash(decoded_tx) == expected_hash

      # Verify recovered from address
      recovered_from = Transaction.Signed.from_address(decoded_tx)
      assert String.downcase(recovered_from) == String.downcase(expected_from)

      # Verify other transaction fields
      assert decoded_tx.payload.chain_id == 1
      assert decoded_tx.payload.gas == 63_628
      assert decoded_tx.payload.max_fee_per_gas == 11_890_834_482
      assert decoded_tx.payload.nonce == 119
      assert decoded_tx.payload.max_priority_fee_per_gas == 8_000_000
      assert decoded_tx.payload.to == "0x8881562783028F5c1BCB985d2283D5E170D88888"
      assert decoded_tx.payload.value == 0

      assert Ethers.Utils.hex_encode(Transaction.encode(decoded_tx)) == raw_tx
    end

    test "decodes raw EIP-2930 transaction and re-encodes it correctly" do
      raw_tx =
        "0x01f903640182dd688503a656ac80830623c4944a137fd5e7a256ef08a7de531a17d0be0cc7b6b680b901a46dbf2fa0000000000000000000000000e592427a0aece92de3edee1f18e0157c05861564000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000104414bf3890000000000000000000000007d1afa7b718fb893db30a3abc0cfc608aacfebb0000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb480000000000000000000000000000000000000000000000000000000000000bb80000000000000000000000004a137fd5e7a256ef08a7de531a17d0be0cc7b6b60000000000000000000000000000000000000000000000000000000060bda78e0000000000000000000000000000000000000000000000cc223b921be6800000000000000000000000000000000000000000000000000000000000017dd4e6ca000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000f90153f87a9407a6e955ba4345bae83ac2a6faa771fddd8a2011f863a00000000000000000000000000000000000000000000000000000000000000000a00000000000000000000000000000000000000000000000000000000000000001a00000000000000000000000000000000000000000000000000000000000000008f87a947d1afa7b718fb893db30a3abc0cfc608aacfebb0f863a014d5312942240e565c56aec11806ce58e3c0e38c96269d759c5d35a2a2e4a449a02701fd0b2638f33db225d91c6adbdad46590a86a09a2b2c386405c2f742af842a037b0b82ee5d8a88672df3895a46af48bbcd30d6efcc908136e29456fa30604bbf85994a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48f842a037570cf18c6d95744a154fa2b19b7e958c78ef68b8c60a80dc527fc15e2ceb8fa06e89d31e3fd8d2bf0b411c458e98c7463bf723878c3ce8a845bcf9dc3b2e391780a01d40605de92c503219631e625ca0d023df8dfef9058896804fb1952d386b64e1a00e0ec0714b7956fe29820cb62998936b78ca4b8a3b05291db90e475244d5c63f"

      expected_from = "0x005FdE5294199d5C3Eb5Eb7a6E51954123b74b1c"
      expected_hash = "0xdb32a678b6c5855eb3c5ff47513e136a85a391469755d045d8846e37fc99d774"

      assert {:ok, decoded_tx} = Transaction.decode(raw_tx)
      assert %Transaction.Signed{payload: %Transaction.Eip2930{}} = decoded_tx

      # Verify transaction hash matches
      assert Transaction.transaction_hash(decoded_tx) == expected_hash

      # Verify recovered from address
      recovered_from = Transaction.Signed.from_address(decoded_tx)
      assert String.downcase(recovered_from) == String.downcase(expected_from)

      # Verify other transaction fields
      assert decoded_tx.payload.chain_id == 1
      assert decoded_tx.payload.gas == 402_372
      assert decoded_tx.payload.gas_price == 15_675_600_000
      assert decoded_tx.payload.nonce == 56_680
      assert decoded_tx.payload.to == "0x4A137FD5e7a256eF08A7De531A17D0BE0cc7B6b6"
      assert decoded_tx.payload.value == 0
      assert Enum.count(decoded_tx.payload.access_list) == 3

      assert Ethers.Utils.hex_encode(Transaction.encode(decoded_tx)) == raw_tx
    end

    test "decodes raw legacy transaction and re-encodes it correctly" do
      raw_tx =
        "0xf86c81c6850c92a69c0082520894e48c9a989438606a79a7560cfba3d34bafbac38e87596f744abf34368025a0ee0b54a64cf8130e36cd1d19395d6d434c285c832a7908873a24610ec32896dfa070b5e779cdcaf5c661c1df44e80895f6ab68463d3ede2cf4955855bc3c6edebb"

      expected_from = "0xB24D14a32CF2fC733209525235937736fC81C1dB"
      expected_hash = "0x5a456fc4bb92a075552d1b8b2ce0e61c75b87a237a8108819ea735d13b7d52aa"

      assert {:ok, decoded_tx} = Transaction.decode(raw_tx)
      assert %Transaction.Signed{payload: %Transaction.Legacy{}} = decoded_tx

      # Verify transaction hash matches
      assert Transaction.transaction_hash(decoded_tx) == expected_hash

      # Verify recovered from address
      recovered_from = Transaction.Signed.from_address(decoded_tx)
      assert String.downcase(recovered_from) == String.downcase(expected_from)

      # Verify other transaction fields
      assert decoded_tx.payload.chain_id == 1
      assert decoded_tx.payload.gas == 21_000
      assert decoded_tx.payload.nonce == 198
      assert decoded_tx.payload.gas_price == 54_000_000_000
      assert decoded_tx.payload.to == "0xe48C9A989438606a79a7560cfba3d34BAfBAC38E"
      assert decoded_tx.payload.value == 25_173_818_188_182_582

      assert Ethers.Utils.hex_encode(Transaction.encode(decoded_tx)) == raw_tx
    end
  end

  test "ensure correct signer type_ids and type_envelopes" do
    types = [
      Transaction.Legacy,
      Transaction.Eip1559,
      Transaction.Eip2930,
      Transaction.Eip4844
    ]

    for type <- types do
      {:ok, tx} =
        type.new(%{
          nonce: 0,
          gas_price: 1,
          gas: 21_000,
          to: nil,
          value: 0,
          input: "",
          chain_id: 1,
          max_priority_fee_per_gas: 1,
          max_fee_per_blob_gas: 1,
          max_fee_per_gas: 1,
          access_list: []
        })

      {:ok, signed_tx} =
        Transaction.Signed.new(%{
          payload: tx,
          signature_r: <<1::256>>,
          signature_s: <<2::256>>,
          signature_y_parity_or_v: 27
        })

      assert Transaction.Protocol.type_id(signed_tx) == type.type_id()
      assert Transaction.Protocol.type_envelope(signed_tx) == type.type_envelope()
    end
  end
end
