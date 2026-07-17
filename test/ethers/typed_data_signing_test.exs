defmodule Ethers.TypedDataSigningTest do
  use ExUnit.Case

  alias Ethers.TypedData

  # @private_key -> 0x90F8bf6A479f320ead074411a4B0e7944Ea8c9C1 (same key used across the suite).
  @private_key "0x4f3edf983ac636a65a842ce7c78d9aa706d3b113bce9c46f30d7d21715b23b1d"
  @address "0x90F8bf6A479f320ead074411a4B0e7944Ea8c9C1"
  @other_address "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266"

  defp mail_typed_data do
    TypedData.new!(
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
        chain_id: 1,
        verifying_contract: "0xCcCCccccCCCCcCCCCCCcCcCccCcCCCcCcccccccC"
      ],
      message: %{
        "from" => %{"name" => "Cow", "wallet" => "0xCD2a3d9F938E13CD947Ec05AbC7FE734Df8DD826"},
        "to" => %{"name" => "Bob", "wallet" => "0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB"},
        "contents" => "Hello, Bob!"
      }
    )
  end

  describe "sign_typed_data/2 with the Local signer" do
    test "signs, recovers the signer, and verifies (round-trip)" do
      td = mail_typed_data()

      assert {:ok, signature} =
               Ethers.sign_typed_data(td,
                 signer: Ethers.Signer.Local,
                 signer_opts: [private_key: @private_key, from: @address]
               )

      assert String.starts_with?(signature, "0x")

      # recover_signer/2 returns the checksummed signer address directly.
      assert TypedData.recover_signer(td, signature) == @address

      assert TypedData.valid_signature?(td, signature, @address)
      # Case-insensitive address comparison.
      assert TypedData.valid_signature?(td, signature, String.downcase(@address))
      refute TypedData.valid_signature?(td, signature, @other_address)
    end

    test "works without an explicit :from (key alone)" do
      td = mail_typed_data()

      assert {:ok, signature} =
               Ethers.sign_typed_data(td,
                 signer: Ethers.Signer.Local,
                 signer_opts: [private_key: @private_key]
               )

      assert TypedData.recover_signer(td, signature) == @address
    end

    test "recover_signer/2 accepts a raw 65-byte binary signature" do
      td = mail_typed_data()

      assert {:ok, signature} =
               Ethers.sign_typed_data(td,
                 signer: Ethers.Signer.Local,
                 signer_opts: [private_key: @private_key]
               )

      raw = Ethers.Utils.hex_decode!(signature)
      assert byte_size(raw) == 65
      assert TypedData.recover_signer(td, raw) == @address
    end
  end

  describe "sign_typed_data!/2" do
    test "returns the raw signature hex" do
      td = mail_typed_data()

      signature =
        Ethers.sign_typed_data!(td,
          signer: Ethers.Signer.Local,
          signer_opts: [private_key: @private_key]
        )

      assert is_binary(signature)
      assert String.starts_with?(signature, "0x")
      assert TypedData.valid_signature?(td, signature, @address)
    end

    test "raises on signer error" do
      td = mail_typed_data()

      assert_raise Ethers.ExecutionError, fn ->
        Ethers.sign_typed_data!(td,
          signer: Ethers.Signer.Local,
          signer_opts: [private_key: @private_key, from: @other_address]
        )
      end
    end
  end
end
