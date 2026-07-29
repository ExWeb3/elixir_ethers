defmodule Ethers.AuthorizationTest do
  use ExUnit.Case

  alias Ethers.Authorization
  alias Ethers.Utils

  doctest Ethers.Authorization

  @delegate "0x2222222222222222222222222222222222222222"
  # Anvil dev account #0
  @authority "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"

  # Signed authorization fixtures produced independently with foundry:
  #   cast wallet sign-auth 0x2222222222222222222222222222222222222222 \
  #     --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
  #     --nonce 7 --chain 1
  @signed_auth_rlp "0xf85a019422222222222222222222222222222222222222220780" <>
                     "a053ed0e60c809fbe7923273de996841403c594d6bd22ecba947fee441f282126a" <>
                     "a038b5b156e99e1b46658a2c1f4240cb8216d876996d3e8882f34846ff81410069"

  #   cast wallet sign-auth 0x2222222222222222222222222222222222222222 \
  #     --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
  #     --nonce 0 --chain 0
  @signed_auth_chain0_rlp "0xf85a809422222222222222222222222222222222222222228001" <>
                            "a0045d07efb041a71d5882ab83f6db7462711c706243275951b4959e50c0410524" <>
                            "a01fbf04884ced7bf18a7679a9a96362d1e0138801daa2ab4b7ba970721de6d5c6"

  @secp256k1n 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141

  describe "new/1" do
    test "creates an authorization from a map or keyword list" do
      assert {:ok, %Authorization{chain_id: 1, address: address, nonce: 7}} =
               Authorization.new(%{chain_id: 1, address: @delegate, nonce: 7})

      assert address == Utils.to_checksum_address(@delegate)

      assert {:ok, %Authorization{}} =
               Authorization.new(chain_id: 1, address: @delegate, nonce: 7)
    end

    test "returns an error for missing fields" do
      assert {:error, :missing_chain_id} = Authorization.new(address: @delegate, nonce: 7)
      assert {:error, :missing_address} = Authorization.new(chain_id: 1, nonce: 7)
      assert {:error, :missing_nonce} = Authorization.new(chain_id: 1, address: @delegate)
    end

    test "returns an error for invalid values" do
      assert {:error, :expected_non_neg_integer_value} =
               Authorization.new(chain_id: -1, address: @delegate, nonce: 7)

      assert {:error, :expected_non_neg_integer_value} =
               Authorization.new(chain_id: 1, address: @delegate, nonce: "7")

      assert {:error, :nonce_out_of_range} =
               Authorization.new(chain_id: 1, address: @delegate, nonce: 2 ** 64)

      assert {:error, :invalid_address} =
               Authorization.new(chain_id: 1, address: "not an address", nonce: 7)

      assert {:error, :invalid_address_length} =
               Authorization.new(chain_id: 1, address: "0x1234", nonce: 7)
    end

    test "new!/1 raises on error" do
      assert_raise ArgumentError, ~r/missing_address/, fn ->
        Authorization.new!(chain_id: 1, nonce: 7)
      end
    end
  end

  describe "clear/1" do
    test "creates an authorization for the zero address" do
      assert {:ok, %Authorization{address: "0x0000000000000000000000000000000000000000"}} =
               Authorization.clear(chain_id: 1, nonce: 8)

      assert %Authorization{address: "0x0000000000000000000000000000000000000000"} =
               Authorization.clear!(chain_id: 1, nonce: 8)
    end

    test "overrides any given address" do
      assert {:ok, %Authorization{address: "0x0000000000000000000000000000000000000000"}} =
               Authorization.clear(chain_id: 1, address: @delegate, nonce: 8)
    end
  end

  describe "hash/1" do
    test "calculates the EIP-7702 signing hash" do
      # Expected value computed independently with foundry:
      #   cast keccak "0x05$(cast to-rlp '["0x01","0x2222...2222","0x07"]' | cut -c3-)"
      authorization = Authorization.new!(chain_id: 1, address: @delegate, nonce: 7)

      assert Utils.hex_encode(Authorization.hash(authorization)) ==
               "0xeb1cce4707677a1968b78c5e74535d51773d66a8d2e291718937e3ddb3d44386"
    end
  end

  describe "Signed.from_rlp_list/1" do
    test "decodes a signed authorization produced by cast" do
      rlp_list = @signed_auth_rlp |> Utils.hex_decode!() |> ExRLP.decode()

      assert {:ok, %Authorization.Signed{} = signed} =
               Authorization.Signed.from_rlp_list(rlp_list)

      assert signed.authorization == Authorization.new!(chain_id: 1, address: @delegate, nonce: 7)
      assert signed.signature_y_parity == 0

      assert Utils.hex_encode(signed.signature_r) ==
               "0x53ed0e60c809fbe7923273de996841403c594d6bd22ecba947fee441f282126a"

      assert Utils.hex_encode(signed.signature_s) ==
               "0x38b5b156e99e1b46658a2c1f4240cb8216d876996d3e8882f34846ff81410069"

      # Re-encoding produces the exact same bytes
      assert signed |> Authorization.Signed.to_rlp_list() |> ExRLP.encode() ==
               Utils.hex_decode!(@signed_auth_rlp)
    end

    test "returns an error for invalid RLP lists" do
      assert {:error, :authorization_decode_failed} = Authorization.Signed.from_rlp_list([])
      assert {:error, :authorization_decode_failed} = Authorization.Signed.from_rlp_list(["", ""])
    end
  end

  describe "Signed.recover_authority/1" do
    test "recovers the authority address" do
      {:ok, signed} =
        @signed_auth_rlp
        |> Utils.hex_decode!()
        |> ExRLP.decode()
        |> Authorization.Signed.from_rlp_list()

      assert {:ok, @authority} = Authorization.Signed.recover_authority(signed)
    end

    test "recovers the authority of a chain-agnostic (chain_id 0) authorization" do
      {:ok, signed} =
        @signed_auth_chain0_rlp
        |> Utils.hex_decode!()
        |> ExRLP.decode()
        |> Authorization.Signed.from_rlp_list()

      assert signed.authorization.chain_id == 0
      assert signed.signature_y_parity == 1
      assert {:ok, @authority} = Authorization.Signed.recover_authority(signed)
    end

    test "rejects high-s signatures which the chain would silently skip" do
      {:ok, signed} =
        @signed_auth_rlp
        |> Utils.hex_decode!()
        |> ExRLP.decode()
        |> Authorization.Signed.from_rlp_list()

      high_s = @secp256k1n - :binary.decode_unsigned(signed.signature_s)
      malleated = %{signed | signature_s: :binary.encode_unsigned(high_s)}

      assert {:error, :invalid_signature_s} = Authorization.Signed.recover_authority(malleated)
    end

    test "rejects invalid y_parity values" do
      {:ok, signed} =
        @signed_auth_rlp
        |> Utils.hex_decode!()
        |> ExRLP.decode()
        |> Authorization.Signed.from_rlp_list()

      assert {:error, :invalid_signature} =
               Authorization.Signed.recover_authority(%{signed | signature_y_parity: 5})
    end
  end
end
