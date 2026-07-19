defmodule Ethers.Signer.LocalTest do
  use ExUnit.Case

  alias Ethers.Signer
  alias Ethers.Transaction.Eip1559
  alias Ethers.Utils

  @private_key "0x4f3edf983ac636a65a842ce7c78d9aa706d3b113bce9c46f30d7d21715b23b1d"

  describe "sign_transaction/2" do
    test "signs the transaction with the correct data" do
      transaction = %Eip1559{
        chain_id: 1337,
        nonce: 2918,
        gas: 23_170,
        to: "0xFFcf8FDEE72ac11b5c542428B35EEF5769C409f0",
        value: 0,
        input: Utils.hex_decode!("0x06fdde03"),
        max_fee_per_gas: 87_119_557_365,
        max_priority_fee_per_gas: 0
      }

      assert {:ok,
              "0x02f86f820539820b6680851448baf2f5825a8294ffcf8fdee72ac11b5c542428b35eef5769c409f0808406fdde03c001a064b0b82fe12d59f11993ea978ef8595a4e21e1c2bb811b083ccb6eed230059fca025e4f674692eb3bbd57505d35a328855d4de4abef31fe26ab2e8eb543cfea285"} ==
               Signer.Local.sign_transaction(transaction, private_key: @private_key)
    end
  end

  describe "sign_typed_data/2" do
    # The canonical EIP-712 Mail/Person payload. Its signing digest is the well-known
    # 0xbe609aee343fb3c4b28e1df9e632fca64fcfaede20f02e86244efddf30957bd2 from the spec.
    defp mail_typed_data(chain_id) do
      Ethers.TypedData.new!(
        types: %{
          "Person" => [
            %{name: "name", type: "string"},
            %{name: "wallet", type: "address"}
          ],
          "Mail" => [
            %{name: "from", type: "Person"},
            %{name: "to", type: "Person"},
            %{name: "contents", type: "string"}
          ]
        },
        primary_type: "Mail",
        domain: [
          name: "Ether Mail",
          version: "1",
          chain_id: chain_id,
          verifying_contract: "0xCcCCccccCCCCcCCCCCCcCcCccCcCCCcCcccccccC"
        ],
        message: %{
          "from" => %{"name" => "Cow", "wallet" => "0xCD2a3d9F938E13CD947Ec05AbC7FE734Df8DD826"},
          "to" => %{"name" => "Bob", "wallet" => "0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB"},
          "contents" => "Hello, Bob!"
        }
      )
    end

    test "produces the exact signature for a fixed key and payload" do
      # Expected signature produced independently by ethers.js v6.17.0 for the same
      # private key (@private_key -> 0x90F8bf6A479f320ead074411a4B0e7944Ea8c9C1) and the
      # canonical Mail payload (domain chainId 1):
      #   const wallet = new ethers.Wallet(pk)
      #   await wallet.signTypedData(domain, types, message)
      # ethers.js digest matched the spec value 0xbe609aee343fb3c4b...30957bd2.
      expected =
        "0x12bdd486cb42c3b3c414bb04253acfe7d402559e7637562987af6bd78508f386" <>
          "23c1cc09880613762cc913d49fd7d3c091be974c0dee83fb233300b6b58727311c"

      assert {:ok, ^expected} =
               Signer.Local.sign_typed_data(mail_typed_data(1), private_key: @private_key)
    end

    test "returns :wrong_key when :from does not match the private key" do
      assert {:error, :wrong_key} =
               Signer.Local.sign_typed_data(mail_typed_data(1),
                 private_key: @private_key,
                 from: "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266"
               )
    end

    test "matches anvil's eth_signTypedData_v4 byte-for-byte" do
      # anvil default account #0 and its published private key.
      from = "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266"

      anvil_private_key =
        "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"

      # Domain chain_id must match anvil (31337) so it accepts the payload. No fixed-bytesN
      # members are used (anvil bytes4 signing bug, foundry#5803).
      typed_data = mail_typed_data(31_337)

      assert {:ok, local_signature} =
               Signer.Local.sign_typed_data(typed_data,
                 private_key: anvil_private_key,
                 from: from
               )

      assert {:ok, anvil_signature} =
               Signer.JsonRPC.sign_typed_data(typed_data, from: from)

      # Deterministic ECDSA over the same digest => identical r || s || v.
      assert local_signature == anvil_signature
    end
  end

  describe "personal_sign/2" do
    # Expected signature generated independently with foundry:
    #   cast wallet sign --private-key <anvil key #0> "Hello world"
    @anvil_private_key "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
    @anvil_address "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
    @hello_world_signature "0x15a3fe3974ebe469b00e67ad67bb3860ad3fc3d739287cdbc4ba558ce7130bee205e5e38d6ef156f1ff6a4df17bfa72a1e61c429f92613f3efbc58394d00c9891b"

    test "produces the exact signature for a fixed key and message" do
      assert {:ok, @hello_world_signature} ==
               Signer.Local.personal_sign("Hello world", private_key: @anvil_private_key)
    end

    test "accepts a matching :from address" do
      assert {:ok, @hello_world_signature} ==
               Signer.Local.personal_sign("Hello world",
                 private_key: @anvil_private_key,
                 from: @anvil_address
               )
    end

    test "returns :wrong_key when :from does not match the private key" do
      assert {:error, :wrong_key} =
               Signer.Local.personal_sign("Hello world",
                 private_key: @anvil_private_key,
                 from: "0x90F8bf6A479f320ead074411a4B0e7944Ea8c9C1"
               )
    end

    test "returns :no_private_key when no key is given" do
      assert {:error, :no_private_key} = Signer.Local.personal_sign("Hello world", [])
    end

    test "matches anvil's personal_sign byte-for-byte" do
      message = "Hello from the JsonRPC signer"

      assert {:ok, local_signature} =
               Signer.Local.personal_sign(message, private_key: @anvil_private_key)

      assert {:ok, anvil_signature} =
               Signer.JsonRPC.personal_sign(message, from: String.downcase(@anvil_address))

      # Deterministic ECDSA over the same digest => identical r || s || v.
      assert local_signature == anvil_signature
    end
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
