defmodule Ethers.TransactionTest do
  use ExUnit.Case

  alias Ethers.Signer
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

    test "decodes raw EIP-7702 transaction and re-encodes it correctly" do
      # Mainnet transaction 0xafc5627648e9d6944f3087e4aeeb11f950de4b0e64ee0caccf7552ba03e01c7e
      # (block 25639950): a sponsor sends a type-4 transaction to the authority EOA, which
      # delegates to 0x69e6bd1C4082403Fc7917a61F6216552fC1a541D and is then called directly.
      raw_tx =
        "0x04f903d101829b81845f355f55845f355f558304016494bcb73594df46001f29143f6853c965684cdaf80380b9030432fba9bb000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000280000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000120000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000044a9059cbb000000000000000000000000d7eefee617ef6251072294e4a0090b816e1b8f3b00000000000000000000000000000000000000000000000000000000004c4b4000000000000000000000000000000000000000000000000000000000000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000044a9059cbb0000000000000000000000009968f86863cd0b7ce2f965fba2ed2749aa36416f0000000000000000000000000000000000000000000000000000000000153eb6000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000041355d1980ed3a88c4dd908723d87313763909184a08b2103f4bfcdb0ba4533eb12ef4968726b9b300e194562bcb0101c19a17a53770251ea8ed1bc6d56d27c9c31b00000000000000000000000000000000000000000000000000000000000000c0f85cf85a019469e6bd1c4082403fc7917a61f6216552fc1a541d0280a03c67c1f1203dd722e316796c37c4b828b98f5a27578627879f415763e2ac5afda04c77aba7874855a80c7357fb13ae953cf9d819a615c00baaa15a2e165a0f08f701a0fcb1caef5bca448a1c02f63ed1e94343bb60cb320f8e3642ef8ceee890b5dc61a05badaf50be7726ae1d0315098e7212492f2b2978685376e4b0ab9ad7c5455eea"

      expected_from = "0x613874e81478ef4213c0ca3fb768b878adb6fd8b"
      expected_hash = "0xafc5627648e9d6944f3087e4aeeb11f950de4b0e64ee0caccf7552ba03e01c7e"

      assert {:ok, decoded_tx} = Transaction.decode(raw_tx)
      assert %Transaction.Signed{payload: %Transaction.Eip7702{}} = decoded_tx

      # Verify transaction hash matches
      assert Transaction.transaction_hash(decoded_tx) == expected_hash

      # Verify recovered from address
      recovered_from = Transaction.Signed.from_address(decoded_tx)
      assert String.downcase(recovered_from) == String.downcase(expected_from)

      # Verify other transaction fields
      assert decoded_tx.payload.chain_id == 1
      assert decoded_tx.payload.gas == 262_500
      assert decoded_tx.payload.max_fee_per_gas == 1_597_333_333
      assert decoded_tx.payload.max_priority_fee_per_gas == 1_597_333_333
      assert decoded_tx.payload.nonce == 39_809
      assert decoded_tx.payload.to == "0xBCb73594df46001F29143f6853C965684cdAF803"
      assert decoded_tx.payload.value == 0
      assert decoded_tx.payload.access_list == []

      # Verify authorization list
      assert [%Ethers.Authorization.Signed{} = signed_auth] =
               decoded_tx.payload.authorization_list

      assert signed_auth.authorization ==
               Ethers.Authorization.new!(
                 chain_id: 1,
                 address: "0x69e6bd1C4082403Fc7917a61F6216552fC1a541D",
                 nonce: 2
               )

      assert signed_auth.signature_y_parity == 0

      assert Utils.hex_encode(signed_auth.signature_r) ==
               "0x3c67c1f1203dd722e316796c37c4b828b98f5a27578627879f415763e2ac5afd"

      assert Utils.hex_encode(signed_auth.signature_s) ==
               "0x4c77aba7874855a80c7357fb13ae953cf9d819a615c00baaa15a2e165a0f08f7"

      # The authority is the account the transaction is sent to (sponsored delegation) —
      # its code on mainnet is the designator 0xef0100 ++ 69e6bd1c...
      assert {:ok, "0xBCb73594df46001F29143f6853C965684cdAF803"} =
               Ethers.Authorization.Signed.recover_authority(signed_auth)

      assert Ethers.Utils.hex_encode(Transaction.encode(decoded_tx)) == raw_tx
    end

    test "returns error for EIP-7702 transaction with empty to address" do
      # Type-4 transactions cannot create contracts, so an empty `to` must be rejected
      authorization_rlp = [
        <<1>>,
        <<0x69E6BD1C4082403FC7917A61F6216552FC1A541D::160>>,
        <<2>>,
        "",
        <<1>>,
        <<1>>
      ]

      raw_tx =
        <<4>> <>
          ExRLP.encode([
            <<1>>,
            "",
            <<1>>,
            <<1>>,
            <<0x5208::16>>,
            "",
            "",
            "",
            [],
            [authorization_rlp]
          ])

      assert {:error, :missing_to_address} = Transaction.decode(raw_tx)
    end

    # Signed with Ethers.Signer.Local by 0x90F8bf6A479f320ead074411a4B0e7944Ea8c9C1, at nonces
    # picked so that RLP decoding strips a leading zero byte from r or s
    test "recovers the sender of a signature whose r has a leading zero byte" do
      raw_tx =
        "0x02f86c8205398201d7830f4240843b9aca008252089470997970c51812dc3a010c7d01b50e0d17dc79c80180c0809fd58955ef700fb477145298696493ccc1aaf44332dc51f190db9ac08356f0e4a04ef7d6df1440caf292931fa4de187bb5671fa46a8fab96b6e69b70faec6ab1e7"

      assert {:ok, decoded_tx} = Transaction.decode(raw_tx)
      assert byte_size(decoded_tx.signature_r) == 31

      assert Transaction.Signed.from_address(decoded_tx) ==
               "0x90F8bf6A479f320ead074411a4B0e7944Ea8c9C1"
    end

    test "recovers the sender of a signature whose s has a leading zero byte" do
      raw_tx =
        "0x02f86a8205391e830f4240843b9aca008252089470997970c51812dc3a010c7d01b50e0d17dc79c80180c080a00497c4b0d78574ce220c14c10d917e18d90e4a4cb3ebe06f812014b3dcdd3ae09f5a890dd8cf4d102fcc55430cd5dfb0c5ff406eb04316b722d12e79ddb95627"

      assert {:ok, decoded_tx} = Transaction.decode(raw_tx)
      assert byte_size(decoded_tx.signature_s) == 31

      assert Transaction.Signed.from_address(decoded_tx) ==
               "0x90F8bf6A479f320ead074411a4B0e7944Ea8c9C1"
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
      Transaction.Eip4844,
      Transaction.Eip7702
    ]

    signed_authorization = %Ethers.Authorization.Signed{
      authorization:
        Ethers.Authorization.new!(
          chain_id: 1,
          address: "0x2222222222222222222222222222222222222222",
          nonce: 0
        ),
      signature_y_parity: 0,
      signature_r: <<1::256>>,
      signature_s: <<2::256>>
    }

    for type <- types do
      {:ok, tx} =
        type.new(%{
          nonce: 0,
          gas_price: 1,
          gas: 21_000,
          to: "0x2222222222222222222222222222222222222222",
          value: 0,
          input: "",
          chain_id: 1,
          max_priority_fee_per_gas: 1,
          max_fee_per_blob_gas: 1,
          max_fee_per_gas: 1,
          access_list: [],
          blob_versioned_hashes: [<<1, 0::248>>],
          authorization_list: [signed_authorization]
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

  # Mainnet transaction 0x224d121387e3bbabfc7bad271b22dddc0dc2743aaf49d850161f628ac9514179
  @signed_eip1559_tx "0x02f8af0177837a12008502c4bfbc3282f88c948881562783028f5c1bcb985d2283d5e170d8888880b844a9059cbb0000000000000000000000002ef7f5c7c727d8845e685f462a5b4f8ac4972a6700000000000000000000000000000000000000000000051ab2ea6fbbb7420000c001a007280557e86f690290f9ea9e26cc17e0cf09a17f6c2d041e95b33be4b81888d0a06c7a24e8fba5cceb455b19950849b9733f0deb92d7e8c2a919f4a82df9c6036a"

  # Mainnet transaction 0x5a456fc4bb92a075552d1b8b2ce0e61c75b87a237a8108819ea735d13b7d52aa
  @signed_legacy_tx "0xf86c81c6850c92a69c0082520894e48c9a989438606a79a7560cfba3d34bafbac38e87596f744abf34368025a0ee0b54a64cf8130e36cd1d19395d6d434c285c832a7908873a24610ec32896dfa070b5e779cdcaf5c661c1df44e80895f6ab68463d3ede2cf4955855bc3c6edebb"

  describe "to_rpc_map/1" do
    test "encodes access list entries as address and storageKeys objects" do
      to = "0x90F8bf6A479f320ead074411a4B0e7944Ea8c9C1"

      access_list = [
        [Utils.hex_decode!(to), [<<1::256>>, <<2::256>>]],
        [<<1::160>>, []]
      ]

      expected_access_list = [
        %{
          address: to,
          storageKeys: [
            "0x0000000000000000000000000000000000000000000000000000000000000001",
            "0x0000000000000000000000000000000000000000000000000000000000000002"
          ]
        },
        %{address: "0x0000000000000000000000000000000000000001", storageKeys: []}
      ]

      {:ok, transaction} =
        Transaction.new(%{
          type: Transaction.Eip2930,
          chain_id: 1,
          nonce: 0,
          gas: 21_000,
          gas_price: 1,
          to: to,
          access_list: access_list
        })

      assert Transaction.to_rpc_map(transaction).accessList == expected_access_list

      # Plain params maps, as built for eth_call and eth_estimateGas
      assert Transaction.to_rpc_map(%{to: to, access_list: access_list}) == %{
               to: to,
               accessList: expected_access_list,
               type: "0x2"
             }
    end

    test "encodes authorization r and s as quantities" do
      address = "0x2222222222222222222222222222222222222222"

      authorization = %Ethers.Authorization.Signed{
        authorization: Ethers.Authorization.new!(chain_id: 1, address: address, nonce: 7),
        signature_y_parity: 1,
        # A 32-byte r with a leading zero byte and a 31-byte s with a leading zero nibble
        signature_r: <<0>> <> :binary.copy(<<0xAB>>, 31),
        signature_s: <<0x0C>> <> :binary.copy(<<0xCD>>, 30)
      }

      {:ok, transaction} =
        Transaction.new(%{
          type: Transaction.Eip7702,
          chain_id: 1,
          nonce: 0,
          gas: 50_000,
          max_fee_per_gas: 1,
          max_priority_fee_per_gas: 1,
          to: address,
          authorization_list: [authorization]
        })

      assert Transaction.to_rpc_map(transaction).authorizationList == [
               %{
                 chainId: "0x1",
                 address: address,
                 nonce: "0x7",
                 yParity: "0x1",
                 r: "0x" <> String.duplicate("AB", 31),
                 s: "0xC" <> String.duplicate("CD", 30)
               }
             ]
    end

    test "keeps the authority of a signed authorization through from_rpc_map/1" do
      address = "0x2222222222222222222222222222222222222222"
      authority = "0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC"

      # The signature is deterministic (RFC 6979); this nonce gives an r with a leading zero byte
      {:ok, signed_authorization} =
        Ethers.Authorization.new!(chain_id: 1, address: address, nonce: 214)
        |> Signer.Local.sign_authorization(
          private_key: "0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a"
        )

      assert <<0, _::binary-31>> = signed_authorization.signature_r

      {:ok, transaction} =
        Transaction.new(%{
          type: Transaction.Eip7702,
          chain_id: 1,
          nonce: 0,
          gas: 50_000,
          max_fee_per_gas: 1,
          max_priority_fee_per_gas: 1,
          to: address,
          authorization_list: [signed_authorization]
        })

      rpc_map = Transaction.to_rpc_map(transaction)

      assert [%{r: "0x78F56157D499B516A55B71B212180CDF4B01C0297DA591B79FC37D32CD2143"}] =
               rpc_map.authorizationList

      assert {:ok, %Transaction.Eip7702{authorization_list: [decoded_authorization]} = decoded} =
               Transaction.from_rpc_map(rpc_map)

      assert {:ok, ^authority} =
               Ethers.Authorization.Signed.recover_authority(signed_authorization)

      assert {:ok, ^authority} =
               Ethers.Authorization.Signed.recover_authority(decoded_authorization)

      assert Transaction.encode(decoded) == Transaction.encode(transaction)
    end

    test "serialises a signed typed transaction with r, s, yParity and v" do
      {:ok, signed} = Transaction.decode(@signed_eip1559_tx)

      assert Transaction.to_rpc_map(signed) == %{
               type: "0x2",
               chainId: "0x1",
               nonce: "0x77",
               maxPriorityFeePerGas: "0x7A1200",
               maxFeePerGas: "0x2C4BFBC32",
               gas: "0xF88C",
               to: "0x8881562783028F5c1BCB985d2283D5E170D88888",
               value: "0x0",
               input:
                 "0xa9059cbb0000000000000000000000002ef7f5c7c727d8845e685f462a5b4f8ac4972a6700000000000000000000000000000000000000000000051ab2ea6fbbb7420000",
               accessList: [],
               # r starts with a zero nibble, which the quantity encoding drops
               r: "0x7280557E86F690290F9EA9E26CC17E0CF09A17F6C2D041E95B33BE4B81888D0",
               s: "0x6C7A24E8FBA5CCEB455B19950849B9733F0DEB92D7E8C2A919F4A82DF9C6036A",
               yParity: "0x1",
               v: "0x1"
             }
    end

    test "serialises a signed legacy transaction with v only" do
      {:ok, signed} = Transaction.decode(@signed_legacy_tx)

      assert Transaction.to_rpc_map(signed) == %{
               type: "0x0",
               chainId: "0x1",
               nonce: "0xC6",
               gasPrice: "0xC92A69C00",
               gas: "0x5208",
               to: "0xe48C9A989438606a79a7560cfba3d34BAfBAC38E",
               value: "0x596F744ABF3436",
               input: "0x",
               r: "0xEE0B54A64CF8130E36CD1D19395D6D434C285C832A7908873A24610EC32896DF",
               s: "0x70B5E779CDCAF5C661C1DF44E80895F6AB68463D3EDE2CF4955855BC3C6EDEBB",
               v: "0x25"
             }
    end

    test "signed transactions read back with from_rpc_map/1" do
      for raw_tx <- [@signed_legacy_tx, @signed_eip1559_tx] do
        {:ok, signed} = Transaction.decode(raw_tx)

        assert {:ok, %Transaction.Signed{} = decoded} =
                 signed |> Transaction.to_rpc_map() |> Transaction.from_rpc_map()

        # from_rpc_map/1 always attaches a metadata struct, empty here
        assert %Transaction.Signed{decoded | metadata: nil} == signed
        assert Transaction.encode(decoded) == Transaction.encode(signed)
      end
    end

    test "includes block metadata when the transaction has it" do
      {:ok, signed} = Transaction.decode(@signed_eip1559_tx)
      refute Map.has_key?(Transaction.to_rpc_map(signed), :blockHash)

      block_hash = "0x" <> String.duplicate("ab", 32)

      rpc_map =
        signed
        |> Transaction.to_rpc_map()
        |> Map.merge(%{blockHash: block_hash, blockNumber: "0x10", transactionIndex: "0x2"})

      assert {:ok, fetched} = Transaction.from_rpc_map(rpc_map)

      assert fetched.metadata == %Transaction.Metadata{
               block_hash: block_hash,
               block_number: 16,
               transaction_index: 2
             }

      assert Transaction.to_rpc_map(fetched) == rpc_map
    end

    test "raises an ArgumentError naming the field for unsupported values" do
      to = "0x90F8bf6A479f320ead074411a4B0e7944Ea8c9C1"

      assert_raise ArgumentError, ~s(Unsupported value "0x10" for transaction field :value), fn ->
        Transaction.to_rpc_map(%{to: to, value: "0x10"})
      end

      # Access list addresses and storage keys are binaries, not hex strings
      assert_raise ArgumentError, ~r/ for transaction field :access_list$/, fn ->
        Transaction.to_rpc_map(%{to: to, access_list: [[to, []]]})
      end

      assert_raise ArgumentError, ~r/ for transaction field :access_list$/, fn ->
        Transaction.to_rpc_map(%{to: to, access_list: [[Utils.hex_decode!(to), ["0x01"]]]})
      end

      assert_raise ArgumentError, ~r/ for transaction field :blob_versioned_hashes$/, fn ->
        Transaction.to_rpc_map(%{to: to, blob_versioned_hashes: ["0x01"]})
      end

      {:ok, %Transaction.Signed{} = signed} = Transaction.decode(@signed_eip1559_tx)

      assert_raise ArgumentError, "Unsupported value 1 for transaction field :signature_r", fn ->
        Transaction.to_rpc_map(%Transaction.Signed{signed | signature_r: 1})
      end
    end
  end

  describe "from_rpc_map/1" do
    test "decodes access list and blob versioned hashes" do
      # eth_getTransactionByHash response for mainnet transaction
      # 0x2a7522ff8773f484123ff169d5a42b4d917d3da5af65baae71f32ab7aeb3dc29
      tx_map = %{
        "type" => "0x3",
        "chainId" => "0x1",
        "nonce" => "0xb3444",
        "to" => "0x1c479675ad559dc151f6ec7ed3fbf8cee79582b6",
        "value" => "0x0",
        "gas" => "0x36fd5",
        "maxFeePerGas" => "0x19a4418ab2",
        "maxPriorityFeePerGas" => "0x7d2b7500",
        "maxFeePerBlobGas" => "0xa",
        "input" =>
          "0x3e5aa08200000000000000000000000000000000000000000000000000000000000bfc5200000000000000000000000000000000000000000000000000000000001bd614000000000000000000000000e64a54e2533fd126c2e452c5fab544d80e2e4eb500000000000000000000000000000000000000000000000000000000101868220000000000000000000000000000000000000000000000000000000010186a47",
        "accessList" => [
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
        ],
        "blobVersionedHashes" => [
          "0x01e74519daf1b03d40e76d557588db2e9b21396f7aeb6086bd794cc4357083ef",
          "0x0169766b1aff3508331a39e7081e591a3ff3bacf957788571269797db7ff3ccc",
          "0x017045639ffe91febe66cc4427fcf6331980dd9a0dab4af3e81c5514b918ed61"
        ],
        "yParity" => "0x0",
        "v" => "0x0",
        "r" => "0x36a73bf3fe4b9a375c2564b2b1a4a795c82b3923225af0a2ab5d7a561b0c4b92",
        "s" => "0x366ac3b831ece20f95d1eac369b1c8d4c2c5ac730655d89c005fe310d1db2086"
      }

      assert {:ok, %Transaction.Signed{payload: %Transaction.Eip4844{} = payload} = transaction} =
               Transaction.from_rpc_map(tx_map)

      assert [
               [
                 <<0x1C479675AD559DC151F6EC7ED3FBF8CEE79582B6::160>>,
                 [<<0::256>>, <<1::256>>, <<10::256>> | _]
               ],
               [<<0x8315177AB297BA92A06054CE80A67ED4DBD7ED3A::160>>, [_, _, _, _, _, _, _, _, _]],
               [<<0xE64A54E2533FD126C2E452C5FAB544D80E2E4EB5::160>>, [_, _, _, _]]
             ] = payload.access_list

      assert payload.blob_versioned_hashes == [
               <<0x01E74519DAF1B03D40E76D557588DB2E9B21396F7AEB6086BD794CC4357083EF::256>>,
               <<0x0169766B1AFF3508331A39E7081E591A3FF3BACF957788571269797DB7FF3CCC::256>>,
               <<0x017045639FFE91FEBE66CC4427FCF6331980DD9A0DAB4AF3E81C5514B918ED61::256>>
             ]

      assert Transaction.transaction_hash(transaction) ==
               "0x2a7522ff8773f484123ff169d5a42b4d917d3da5af65baae71f32ab7aeb3dc29"

      assert {:ok, ^transaction} =
               transaction |> Transaction.to_rpc_map() |> Transaction.from_rpc_map()
    end

    test "decodes access list entries with atom keys" do
      tx_map = %{
        type: "0x1",
        chainId: "0x1",
        nonce: "0x0",
        to: "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb5",
        value: "0x0",
        input: "0x",
        gas: "0x5208",
        gasPrice: "0x3b9aca00",
        accessList: [
          %{
            address: "0x742d35cc6634c0532925a3b844bc9e7595f0beb5",
            storageKeys: ["0x0000000000000000000000000000000000000000000000000000000000000001"]
          },
          %{address: "0x0000000000000000000000000000000000000001", storageKeys: []}
        ]
      }

      assert {:ok, %Transaction.Eip2930{access_list: access_list}} =
               Transaction.from_rpc_map(tx_map)

      assert access_list == [
               [<<0x742D35CC6634C0532925A3B844BC9E7595F0BEB5::160>>, [<<1::256>>]],
               [<<1::160>>, []]
             ]
    end

    test "handles transaction with input field" do
      tx_map = %{
        "type" => "0x2",
        "chainId" => "0x1",
        "nonce" => "0x0",
        "to" => "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb5",
        "value" => "0x0",
        "input" => "0x1234567890",
        "gas" => "0x5208",
        "maxFeePerGas" => "0x3b9aca00",
        "maxPriorityFeePerGas" => "0x0"
      }

      assert {:ok, transaction} = Transaction.from_rpc_map(tx_map)
      assert transaction.input == Utils.hex_decode!("0x1234567890")
    end

    test "handles transaction with data field instead of input" do
      tx_map = %{
        "type" => "0x2",
        "chainId" => "0x1",
        "nonce" => "0x0",
        "to" => "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb5",
        "value" => "0x0",
        "data" => "0xabcdef",
        "gas" => "0x5208",
        "maxFeePerGas" => "0x3b9aca00",
        "maxPriorityFeePerGas" => "0x0"
      }

      assert {:ok, transaction} = Transaction.from_rpc_map(tx_map)
      assert transaction.input == Utils.hex_decode!("0xabcdef")
    end

    test "handles transaction with both input and data fields (input takes precedence)" do
      tx_map = %{
        "type" => "0x2",
        "chainId" => "0x1",
        "nonce" => "0x0",
        "to" => "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb5",
        "value" => "0x0",
        "input" => "0x1234",
        "data" => "0x5678",
        "gas" => "0x5208",
        "maxFeePerGas" => "0x3b9aca00",
        "maxPriorityFeePerGas" => "0x0"
      }

      assert {:ok, transaction} = Transaction.from_rpc_map(tx_map)
      assert transaction.input == Utils.hex_decode!("0x1234")
    end

    test "handles transaction with neither input nor data field (defaults to empty string)" do
      tx_map = %{
        "type" => "0x2",
        "chainId" => "0x1",
        "nonce" => "0x0",
        "to" => "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb5",
        "value" => "0x0",
        "gas" => "0x5208",
        "maxFeePerGas" => "0x3b9aca00",
        "maxPriorityFeePerGas" => "0x0"
      }

      assert {:ok, transaction} = Transaction.from_rpc_map(tx_map)
      assert transaction.input == ""
    end

    test "handles transaction with nil input and data fields" do
      tx_map = %{
        "type" => "0x2",
        "chainId" => "0x1",
        "nonce" => "0x0",
        "to" => "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb5",
        "value" => "0x0",
        "input" => nil,
        "data" => nil,
        "gas" => "0x5208",
        "maxFeePerGas" => "0x3b9aca00",
        "maxPriorityFeePerGas" => "0x0"
      }

      assert {:ok, transaction} = Transaction.from_rpc_map(tx_map)
      assert transaction.input == ""
    end

    test "handles transaction with atom keys" do
      tx_map = %{
        type: "0x2",
        chainId: "0x1",
        nonce: "0x0",
        to: "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb5",
        value: "0x0",
        input: "0xdeadbeef",
        gas: "0x5208",
        maxFeePerGas: "0x3b9aca00",
        maxPriorityFeePerGas: "0x0"
      }

      assert {:ok, transaction} = Transaction.from_rpc_map(tx_map)
      assert transaction.input == Utils.hex_decode!("0xdeadbeef")
      assert %Transaction.Eip1559{} = transaction
    end

    test "handles legacy transaction type" do
      tx_map = %{
        "type" => "0x0",
        "chainId" => "0x1",
        "nonce" => "0x0",
        "to" => "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb5",
        "value" => "0x0",
        "data" => "0xaabbcc",
        "gas" => "0x5208",
        "gasPrice" => "0x3b9aca00"
      }

      assert {:ok, transaction} = Transaction.from_rpc_map(tx_map)
      assert transaction.input == Utils.hex_decode!("0xaabbcc")
      assert %Transaction.Legacy{} = transaction
    end

    test "handles EIP-2930 transaction type" do
      tx_map = %{
        "type" => "0x1",
        "chainId" => "0x1",
        "nonce" => "0x0",
        "to" => "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb5",
        "value" => "0x0",
        "input" => "0x112233",
        "gas" => "0x5208",
        "gasPrice" => "0x3b9aca00",
        "accessList" => []
      }

      assert {:ok, transaction} = Transaction.from_rpc_map(tx_map)
      assert transaction.input == Utils.hex_decode!("0x112233")
      assert %Transaction.Eip2930{} = transaction
    end

    test "handles EIP-7702 transaction type" do
      # Authorization entry shaped exactly like an eth_getTransactionByHash response
      # (mainnet tx 0xafc5627648e9d6944f3087e4aeeb11f950de4b0e64ee0caccf7552ba03e01c7e)
      tx_map = %{
        "type" => "0x4",
        "chainId" => "0x1",
        "nonce" => "0x9b81",
        "to" => "0xbcb73594df46001f29143f6853c965684cdaf803",
        "value" => "0x0",
        "input" => "0x32fba9bb",
        "gas" => "0x40164",
        "maxFeePerGas" => "0x5f355f55",
        "maxPriorityFeePerGas" => "0x5f355f55",
        "accessList" => [],
        "authorizationList" => [
          %{
            "chainId" => "0x1",
            "address" => "0x69e6bd1c4082403fc7917a61f6216552fc1a541d",
            "nonce" => "0x2",
            "yParity" => "0x0",
            "r" => "0x3c67c1f1203dd722e316796c37c4b828b98f5a27578627879f415763e2ac5afd",
            "s" => "0x4c77aba7874855a80c7357fb13ae953cf9d819a615c00baaa15a2e165a0f08f7"
          }
        ]
      }

      assert {:ok, %Transaction.Eip7702{} = transaction} = Transaction.from_rpc_map(tx_map)

      assert [%Ethers.Authorization.Signed{} = signed_auth] = transaction.authorization_list

      assert signed_auth.authorization ==
               Ethers.Authorization.new!(
                 chain_id: 1,
                 address: "0x69e6bd1C4082403Fc7917a61F6216552fC1a541D",
                 nonce: 2
               )

      assert signed_auth.signature_y_parity == 0

      # Round-trips back to the RPC representation
      rpc_map = Transaction.to_rpc_map(transaction)
      assert rpc_map.type == "0x4"

      assert rpc_map.authorizationList == [
               %{
                 chainId: "0x1",
                 address: "0x69e6bd1C4082403Fc7917a61F6216552fC1a541D",
                 nonce: "0x2",
                 yParity: "0x0",
                 r: "0x3C67C1F1203DD722E316796C37C4B828B98F5A27578627879F415763E2AC5AFD",
                 s: "0x4C77ABA7874855A80C7357FB13AE953CF9D819A615C00BAAA15A2E165A0F08F7"
               }
             ]
    end

    test "returns error for missing authorization list in EIP-7702 transaction" do
      tx_map = %{
        "type" => "0x4",
        "chainId" => "0x1",
        "nonce" => "0x0",
        "to" => "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb5",
        "value" => "0x0",
        "gas" => "0x5208",
        "maxFeePerGas" => "0x3b9aca00",
        "maxPriorityFeePerGas" => "0x0"
      }

      assert {:error, :empty_authorization_list} = Transaction.from_rpc_map(tx_map)
    end
  end
end
