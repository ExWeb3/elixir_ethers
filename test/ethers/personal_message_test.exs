defmodule Ethers.PersonalMessageTest.NoMessageSigner do
  @moduledoc false
  # A signer that implements the required callbacks but NOT the optional `personal_sign/2`.
  @behaviour Ethers.Signer

  @impl true
  def sign_transaction(_tx, _opts), do: {:error, :not_supported}

  @impl true
  def accounts(_opts), do: {:error, :not_supported}
end

defmodule Ethers.PersonalMessageTest.BuggySigner do
  @moduledoc false
  # A signer whose `personal_sign/2` raises an UndefinedFunctionError for a *different*
  # module — it must be re-raised, not translated to {:error, :not_supported}.
  @behaviour Ethers.Signer

  @impl true
  def sign_transaction(_tx, _opts), do: {:error, :not_supported}

  @impl true
  def accounts(_opts), do: {:error, :not_supported}

  @impl true
  def personal_sign(_message, _opts) do
    module = Module.concat(__MODULE__, NonExistent)
    module.call()
  end
end

defmodule Ethers.PersonalMessageTest do
  use ExUnit.Case, async: true

  alias Ethers.PersonalMessage
  alias Ethers.PersonalMessageTest.NoMessageSigner
  alias Ethers.Utils

  doctest Ethers.PersonalMessage

  # Well-known anvil/hardhat development keys.
  @private_key "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
  @address "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
  @other_private_key "0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d"
  @other_address "0x70997970C51812dc3A010C7d01b50e0d17dc79C8"

  # Ground-truth vectors generated with foundry:
  # `cast hash-message <msg>` and `cast wallet sign --private-key <key> <msg>`
  @vectors [
    %{
      message: "Hello world",
      key: @private_key,
      address: @address,
      hash: "0x8144a6fa26be252b86456491fbcd43c1de7e022241845ffea1c3df066f7cfede",
      signature:
        "0x15a3fe3974ebe469b00e67ad67bb3860ad3fc3d739287cdbc4ba558ce7130bee205e5e38d6ef156f1ff6a4df17bfa72a1e61c429f92613f3efbc58394d00c9891b"
    },
    %{
      message: "",
      key: @private_key,
      address: @address,
      hash: "0x5f35dce98ba4fba25530a026ed80b2cecdaa31091ba4958b99b52ea1d068adad",
      signature:
        "0xc1977b761f1dd36c29795783460d241885c8e7f9d962dbe7bba2753fd94e89b444a1cd9ed855dd09afa3b73f7c2bd097ec9abc2d2775d737505a02d3f0cafa591b"
    },
    %{
      message: "héllo wörld ⚡",
      key: @other_private_key,
      address: @other_address,
      hash: "0xd5a255506d3e767277bde6078f42d4ef18ad3212630b5809d97df20548863b93",
      signature:
        "0xe02ed32b4483d5a6994deda655065e91f3950445b1d953f650b2729833934cf069540544671d86db7da92056d965924cee2b5542a0e534ec08db789b8472a0021b"
    },
    %{
      # `cast wallet sign 0xdeadbeef` hex-decodes and signs the *raw bytes*; in Elixir raw
      # bytes are just a binary, so the equivalent input is <<0xDE, 0xAD, 0xBE, 0xEF>>.
      # Hash cross-checked with `printf '\x19Ethereum Signed Message:\n4\xde\xad\xbe\xef' | cast keccak`.
      message: <<0xDE, 0xAD, 0xBE, 0xEF>>,
      key: @other_private_key,
      address: @other_address,
      hash: "0xd1c7f1a06a4f9a535077e50ad23244ce2c6ae443fcd412965226f3df5d28eaaa",
      signature:
        "0xa443ea4651a6a91569bb9924b5eba4c2e267a0c922f5dec2036cdc460b004fbc5f4082976d9815d70815f4661d27e9ab4ab5b60eb417bcfc23b3d2a4dab9b5891c"
    }
  ]

  describe "hash/1" do
    test "matches the reference EIP-191 (version 0x45) hashes" do
      for vector <- @vectors do
        assert PersonalMessage.hash(vector.message) == Utils.hex_decode!(vector.hash),
               "hash mismatch for message #{inspect(vector.message)}"
      end
    end

    test "returns a 32-byte binary" do
      assert <<_::binary-size(32)>> = PersonalMessage.hash("Hello world")
    end

    test "treats a 0x-prefixed string as literal text, not hex bytes" do
      # "0xdeadbeef" as *text* is 10 bytes and must NOT hash like the 4 raw bytes.
      refute PersonalMessage.hash("0xdeadbeef") ==
               PersonalMessage.hash(<<0xDE, 0xAD, 0xBE, 0xEF>>)

      # Reference for the literal-text semantics: `cast hash-message 0xdeadbeef` (which,
      # unlike `cast wallet sign`, treats its argument as a plain string).
      assert PersonalMessage.hash("0xdeadbeef") ==
               Utils.hex_decode!(
                 "0xefedd0a9a0294228c3977d7fbb68c7d40279f8b408cf3e24ef1823b179709e58"
               )
    end
  end

  describe "recover/2" do
    test "recovers the checksummed signer address from the reference vectors" do
      for vector <- @vectors do
        assert {:ok, vector.address} == PersonalMessage.recover(vector.message, vector.signature),
               "recover mismatch for message #{inspect(vector.message)}"
      end
    end

    test "accepts a raw 65-byte binary signature" do
      [vector | _] = @vectors
      raw = Utils.hex_decode!(vector.signature)
      assert byte_size(raw) == 65
      assert {:ok, vector.address} == PersonalMessage.recover(vector.message, raw)
    end

    test "accepts v as raw parity (0/1) as well as 27/28" do
      [vector | _] = @vectors
      <<body::binary-size(64), v::integer>> = Utils.hex_decode!(vector.signature)
      assert v in [27, 28]

      assert {:ok, vector.address} ==
               PersonalMessage.recover(vector.message, <<body::binary, v - 27>>)
    end

    test "returns {:error, :invalid_signature} for a wrong-length binary" do
      assert {:error, :invalid_signature} = PersonalMessage.recover("Hello world", <<1, 2, 3>>)
    end

    test "returns {:error, :invalid_signature} for a wrong-length hex string" do
      assert {:error, :invalid_signature} = PersonalMessage.recover("Hello world", "0xdeadbeef")
    end

    test "returns {:error, :invalid_signature} for non-hex input" do
      assert {:error, :invalid_signature} =
               PersonalMessage.recover("Hello world", "0xnothexatall")
    end

    test "returns {:error, :invalid_signature} for an out-of-range v" do
      [vector | _] = @vectors
      <<body::binary-size(64), _v::integer>> = Utils.hex_decode!(vector.signature)

      assert {:error, :invalid_signature} =
               PersonalMessage.recover(vector.message, <<body::binary, 29>>)
    end
  end

  describe "recover!/2" do
    test "returns the address directly" do
      [vector | _] = @vectors
      assert PersonalMessage.recover!(vector.message, vector.signature) == vector.address
    end

    test "raises on a malformed signature" do
      assert_raise Ethers.ExecutionError, fn ->
        PersonalMessage.recover!("Hello world", "0xdeadbeef")
      end
    end
  end

  describe "verify/3" do
    test "returns true for the reference vectors" do
      for vector <- @vectors do
        assert PersonalMessage.verify(vector.message, vector.signature, vector.address)
      end
    end

    test "compares addresses case-insensitively" do
      [vector | _] = @vectors
      "0x" <> address_hex = vector.address

      assert PersonalMessage.verify(
               vector.message,
               vector.signature,
               String.downcase(vector.address)
             )

      assert PersonalMessage.verify(
               vector.message,
               vector.signature,
               "0x" <> String.upcase(address_hex)
             )
    end

    test "returns false for a different address" do
      [vector | _] = @vectors
      refute PersonalMessage.verify(vector.message, vector.signature, @other_address)
    end

    test "returns false for a different message" do
      [vector | _] = @vectors
      refute PersonalMessage.verify("Goodbye world", vector.signature, vector.address)
    end

    test "returns false (does not raise) on a malformed signature" do
      refute PersonalMessage.verify("Hello world", "0xdeadbeef", @address)
    end
  end

  describe "Ethers.personal_sign/2 with the Local signer" do
    test "produces the exact reference signature for each vector" do
      for vector <- @vectors do
        assert {:ok, vector.signature} ==
                 Ethers.personal_sign(vector.message,
                   signer: Ethers.Signer.Local,
                   signer_opts: [private_key: vector.key]
                 ),
               "signature mismatch for message #{inspect(vector.message)}"
      end
    end

    test "signs, recovers, and verifies (round-trip)" do
      message = "sign in to example.com"

      assert {:ok, signature} =
               Ethers.personal_sign(message,
                 signer: Ethers.Signer.Local,
                 signer_opts: [private_key: @private_key, from: @address]
               )

      assert {:ok, @address} = PersonalMessage.recover(message, signature)
      assert PersonalMessage.verify(message, signature, @address)
      refute PersonalMessage.verify(message, signature, @other_address)
    end

    test "signs a 0x-prefixed string as literal text (round-trip)" do
      message = "0xdeadbeef"

      assert {:ok, signature} =
               Ethers.personal_sign(message,
                 signer: Ethers.Signer.Local,
                 signer_opts: [private_key: @private_key]
               )

      assert {:ok, @address} = PersonalMessage.recover(message, signature)
      # And it is NOT the signature over the raw bytes 0xde 0xad 0xbe 0xef.
      refute PersonalMessage.verify(<<0xDE, 0xAD, 0xBE, 0xEF>>, signature, @address)
    end

    test "returns :wrong_key when :from does not match the private key" do
      assert {:error, :wrong_key} =
               Ethers.personal_sign("Hello world",
                 signer: Ethers.Signer.Local,
                 signer_opts: [private_key: @private_key, from: @other_address]
               )
    end
  end

  describe "Ethers.personal_sign!/2" do
    test "returns the raw signature hex" do
      [vector | _] = @vectors

      signature =
        Ethers.personal_sign!(vector.message,
          signer: Ethers.Signer.Local,
          signer_opts: [private_key: vector.key]
        )

      assert signature == vector.signature
    end

    test "raises on signer error" do
      assert_raise Ethers.ExecutionError, fn ->
        Ethers.personal_sign!("Hello world",
          signer: Ethers.Signer.Local,
          signer_opts: [private_key: @private_key, from: @other_address]
        )
      end
    end
  end

  describe "unsupported signer" do
    test "returns {:error, :not_supported} when the signer does not implement the callback" do
      assert {:error, :not_supported} =
               Ethers.personal_sign("Hello world", signer: NoMessageSigner)
    end

    test "re-raises UndefinedFunctionError coming from within the signer" do
      assert_raise UndefinedFunctionError, ~r/NonExistent/, fn ->
        Ethers.personal_sign("Hello world", signer: Ethers.PersonalMessageTest.BuggySigner)
      end
    end
  end
end
