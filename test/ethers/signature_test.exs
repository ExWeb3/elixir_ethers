defmodule Ethers.SignatureTest.RaisingRpcModule do
  @moduledoc false
  # Used to prove code paths that must not hit the network.

  def eth_call(_params, _block, _opts) do
    raise "eth_call must not be called in this code path"
  end
end

defmodule Ethers.SignatureTest.ErrorRpcModule do
  @moduledoc false
  # Simulates an RPC transport failure.

  def eth_call(_params, _block, _opts), do: {:error, :nxdomain}
end

defmodule Ethers.SignatureTest.MessageErrorRpcModule do
  @moduledoc false
  # Simulates JSON-RPC error responses carrying only a message (no error code).

  def eth_call(_params, _block, opts), do: {:error, %{"message" => opts[:message]}}
end

defmodule Ethers.SignatureTest.EchoRpcModule do
  @moduledoc false
  # Sends the eth_call params back to the test process and returns a canned result.

  def eth_call(params, block, opts) do
    send(opts[:send_params_to_pid], {:eth_call, params, block})
    {:ok, opts[:result] || "0x01"}
  end
end

defmodule Ethers.Contract.Test.ERC1271WalletContract do
  @moduledoc false
  use Ethers.Contract, abi_file: "tmp/erc1271_wallet_abi.json"
end

defmodule Ethers.Contract.Test.Create2FactoryContract do
  @moduledoc false
  use Ethers.Contract, abi_file: "tmp/create2_factory_abi.json"
end

defmodule Ethers.SignatureTest do
  use ExUnit.Case

  import Ethers.TestHelpers

  alias Ethers.Contract.Test.Create2FactoryContract
  alias Ethers.Contract.Test.ERC1271WalletContract
  alias Ethers.Contracts.UniversalSigValidator
  alias Ethers.PersonalMessage
  alias Ethers.Signature
  alias Ethers.SignatureTest.EchoRpcModule
  alias Ethers.SignatureTest.ErrorRpcModule
  alias Ethers.SignatureTest.MessageErrorRpcModule
  alias Ethers.SignatureTest.RaisingRpcModule
  alias Ethers.TypedData
  alias Ethers.Utils

  # 0x90F8bf6A479f320ead074411a4B0e7944Ea8c9C1 (same key used across the suite)
  @owner_private_key "0x4f3edf983ac636a65a842ce7c78d9aa706d3b113bce9c46f30d7d21715b23b1d"
  @owner "0x90F8bf6A479f320ead074411a4B0e7944Ea8c9C1"
  # First anvil dev account (funded, unlocked) — used to send deployment transactions
  @from "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
  @other_private_key "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"

  @erc6492_magic_suffix <<0x6492649264926492649264926492649264926492649264926492649264926492::256>>

  defp typed_data do
    TypedData.new!(
      types: %{
        "Person" => [
          %{name: "name", type: "string"},
          %{name: "wallet", type: "address"}
        ]
      },
      primary_type: "Person",
      domain: [name: "Ether Person", version: "1", chain_id: 1],
      message: %{"name" => "Cow", "wallet" => "0xCD2a3d9F938E13CD947Ec05AbC7FE734Df8DD826"}
    )
  end

  # Signs a raw 32-byte digest (no EIP-191 prefixing) with the given hex private key,
  # returning a 65-byte `r ‖ s ‖ v` signature with v ∈ {27, 28}.
  defp sign_digest(digest, private_key_hex) do
    private_key = Utils.hex_decode!(private_key_hex)
    {:ok, {r, s, recovery_id}} = Ethers.secp256k1_module().sign(digest, private_key)
    r <> s <> <<recovery_id + 27>>
  end

  defp deploy_wallet(owner) do
    encoded_constructor = ERC1271WalletContract.constructor(owner)
    deploy(ERC1271WalletContract, encoded_constructor: encoded_constructor, from: @from)
  end

  defp wrap_6492(factory, factory_calldata, signature) do
    [Utils.decode_address!(factory), factory_calldata, signature]
    |> ABI.TypeEncoder.encode([:address, :bytes, :bytes])
    |> Kernel.<>(@erc6492_magic_suffix)
  end

  describe "verify_hash/4 EOA fast path" do
    test "verifies a personal message signature without any RPC call" do
      {:ok, signature} =
        Ethers.personal_sign("Hello 6492",
          signer: Ethers.Signer.Local,
          signer_opts: [private_key: @owner_private_key]
        )

      hash = PersonalMessage.hash("Hello 6492")

      assert {:ok, true} =
               Signature.verify_hash(hash, signature, @owner, rpc_client: RaisingRpcModule)
    end

    test "accepts raw binary signatures and hex hashes" do
      hash = PersonalMessage.hash("raw binary")
      signature = sign_digest(hash, @owner_private_key)

      assert {:ok, true} =
               Signature.verify_hash(hash, signature, @owner, rpc_client: RaisingRpcModule)

      assert {:ok, true} =
               Signature.verify_hash(
                 Utils.hex_encode(hash),
                 signature,
                 @owner,
                 rpc_client: RaisingRpcModule
               )
    end

    test "ignores address casing" do
      hash = PersonalMessage.hash("casing")
      signature = sign_digest(hash, @owner_private_key)

      assert {:ok, true} =
               Signature.verify_hash(
                 hash,
                 signature,
                 String.downcase(@owner),
                 rpc_client: RaisingRpcModule
               )
    end

    test "accepts v ∈ {0, 1} parity signatures" do
      hash = PersonalMessage.hash("parity")
      <<r_s::binary-size(64), v>> = sign_digest(hash, @owner_private_key)
      parity_signature = r_s <> <<v - 27>>

      assert {:ok, true} =
               Signature.verify_hash(hash, parity_signature, @owner, rpc_client: RaisingRpcModule)
    end
  end

  describe "verify_hash/4 validator fallback (deployless eth_call)" do
    test "returns false for a valid signature by a different address" do
      hash = PersonalMessage.hash("wrong signer")
      signature = sign_digest(hash, @other_private_key)

      assert {:ok, false} = Signature.verify_hash(hash, signature, @owner)
    end

    test "returns false for a 65-byte garbage signature" do
      hash = PersonalMessage.hash("garbage")
      garbage = :binary.copy(<<1>>, 64) <> <<27>>

      assert {:ok, false} = Signature.verify_hash(hash, garbage, @owner)
    end

    test "returns false for an all-zero signature (local recovery fails)" do
      hash = PersonalMessage.hash("zeros")
      zero_signature = :binary.copy(<<0>>, 64) <> <<27>>

      assert {:ok, false} = Signature.verify_hash(hash, zero_signature, @owner)
    end

    test "returns false for a signature with invalid length (validator reverts)" do
      hash = PersonalMessage.hash("short")
      short = :binary.copy(<<1>>, 64)

      assert {:ok, false} = Signature.verify_hash(hash, short, @owner)
    end

    test "sends a deployless call: no `to`, data = creation code <> constructor args" do
      hash = PersonalMessage.hash("deployless")
      signature = sign_digest(hash, @other_private_key)

      assert {:ok, true} =
               Signature.verify_hash(hash, signature, @owner,
                 rpc_client: EchoRpcModule,
                 rpc_opts: [send_params_to_pid: self(), result: "0x01"]
               )

      assert_receive {:eth_call, params, "latest"}
      refute Map.has_key?(params, :to)

      expected_prefix = Utils.hex_encode(UniversalSigValidator.creation_code())
      assert String.starts_with?(params.data, expected_prefix)
    end

    test "supports the :block option" do
      hash = PersonalMessage.hash("block option")
      signature = sign_digest(hash, @other_private_key)

      assert {:ok, true} =
               Signature.verify_hash(hash, signature, @owner,
                 block: 123,
                 rpc_client: EchoRpcModule,
                 rpc_opts: [send_params_to_pid: self(), result: "0x01"]
               )

      assert_receive {:eth_call, _params, "0x7B"}
    end

    test "returns an error for unexpected validator results" do
      hash = PersonalMessage.hash("unexpected")
      signature = sign_digest(hash, @other_private_key)

      assert {:error, {:unexpected_result, "0xdeadbeef"}} =
               Signature.verify_hash(hash, signature, @owner,
                 rpc_client: EchoRpcModule,
                 rpc_opts: [send_params_to_pid: self(), result: "0xdeadbeef"]
               )
    end
  end

  describe "ERC-1271 deployed smart-contract wallet" do
    setup do
      %{wallet: deploy_wallet(@owner)}
    end

    test "verifies a signature by the wallet owner", %{wallet: wallet} do
      hash = PersonalMessage.hash("hello 1271")
      signature = sign_digest(hash, @owner_private_key)

      assert {:ok, true} = Signature.verify_hash(hash, signature, wallet)
    end

    test "rejects a signature by a non-owner", %{wallet: wallet} do
      hash = PersonalMessage.hash("hello 1271")
      signature = sign_digest(hash, @other_private_key)

      assert {:ok, false} = Signature.verify_hash(hash, signature, wallet)
    end

    test "verify_message/4 works for smart-contract wallets", %{wallet: wallet} do
      message = "sign in please"
      signature = sign_digest(PersonalMessage.hash(message), @owner_private_key)

      assert {:ok, true} = Signature.verify_message(message, signature, wallet)
      assert {:ok, false} = Signature.verify_message("some other message", signature, wallet)
    end

    test "verify_typed_data/4 works for smart-contract wallets", %{wallet: wallet} do
      signature = sign_digest(TypedData.hash(typed_data()), @owner_private_key)

      assert {:ok, true} = Signature.verify_typed_data(typed_data(), signature, wallet)
    end
  end

  describe "ERC-6492 counterfactual (not-yet-deployed) wallet" do
    setup do
      factory = deploy(Create2FactoryContract, from: @from)

      salt = <<42::256>>

      init_code =
        ERC1271WalletContract.__contract_binary__() <>
          ABI.TypeEncoder.encode([Utils.decode_address!(@owner)], [:address])

      counterfactual_address =
        <<0xFF, Utils.decode_address!(factory)::binary, salt::binary,
          Ethers.keccak_module().hash_256(init_code)::binary>>
        |> Ethers.keccak_module().hash_256()
        |> binary_part(12, 20)
        |> Utils.encode_address!()

      factory_calldata = Create2FactoryContract.deploy(salt, init_code).data

      %{
        factory: factory,
        salt: salt,
        init_code: init_code,
        counterfactual_address: counterfactual_address,
        factory_calldata: factory_calldata
      }
    end

    test "verifies a wrapped signature for an undeployed wallet", ctx do
      # The wallet must not exist yet
      assert {:ok, "0x"} =
               Ethereumex.HttpClient.eth_get_code(String.downcase(ctx.counterfactual_address))

      hash = PersonalMessage.hash("counterfactual hello")
      signature = sign_digest(hash, @owner_private_key)
      wrapped = wrap_6492(ctx.factory, ctx.factory_calldata, signature)

      assert {:ok, true} = Signature.verify_hash(hash, wrapped, ctx.counterfactual_address)

      # verify_hash must not have deployed anything (eth_call only)
      assert {:ok, "0x"} =
               Ethereumex.HttpClient.eth_get_code(String.downcase(ctx.counterfactual_address))
    end

    test "accepts hex-encoded wrapped signatures", ctx do
      hash = PersonalMessage.hash("hex wrapped")
      signature = sign_digest(hash, @owner_private_key)
      wrapped = Utils.hex_encode(wrap_6492(ctx.factory, ctx.factory_calldata, signature))

      assert {:ok, true} = Signature.verify_hash(hash, wrapped, ctx.counterfactual_address)
    end

    test "rejects a wrapped signature by a non-owner", ctx do
      hash = PersonalMessage.hash("counterfactual hello")
      signature = sign_digest(hash, @other_private_key)
      wrapped = wrap_6492(ctx.factory, ctx.factory_calldata, signature)

      assert {:ok, false} = Signature.verify_hash(hash, wrapped, ctx.counterfactual_address)
    end
  end

  describe "verify_message/4 and verify_typed_data/4 (EOA)" do
    test "verify_message verifies EOA signatures without RPC" do
      {:ok, signature} =
        Ethers.personal_sign("hi",
          signer: Ethers.Signer.Local,
          signer_opts: [private_key: @owner_private_key]
        )

      assert {:ok, true} =
               Signature.verify_message("hi", signature, @owner, rpc_client: RaisingRpcModule)
    end

    test "verify_message returns false for the wrong address" do
      {:ok, signature} =
        Ethers.personal_sign("hi",
          signer: Ethers.Signer.Local,
          signer_opts: [private_key: @other_private_key]
        )

      assert {:ok, false} = Signature.verify_message("hi", signature, @owner)
    end

    test "verify_typed_data verifies EOA signatures without RPC" do
      {:ok, signature} =
        Ethers.sign_typed_data(typed_data(),
          signer: Ethers.Signer.Local,
          signer_opts: [private_key: @owner_private_key]
        )

      assert {:ok, true} =
               Signature.verify_typed_data(typed_data(), signature, @owner,
                 rpc_client: RaisingRpcModule
               )
    end

    test "verify_typed_data returns false for the wrong address" do
      {:ok, signature} =
        Ethers.sign_typed_data(typed_data(),
          signer: Ethers.Signer.Local,
          signer_opts: [private_key: @other_private_key]
        )

      assert {:ok, false} = Signature.verify_typed_data(typed_data(), signature, @owner)
    end
  end

  describe "error handling" do
    test "propagates RPC transport errors" do
      hash = PersonalMessage.hash("transport error")
      signature = sign_digest(hash, @other_private_key)

      assert {:error, :nxdomain} =
               Signature.verify_hash(hash, signature, @owner, rpc_client: ErrorRpcModule)
    end

    test "treats revert-message-only RPC errors as an invalid signature" do
      hash = PersonalMessage.hash("revert message")
      signature = sign_digest(hash, @other_private_key)

      assert {:ok, false} =
               Signature.verify_hash(hash, signature, @owner,
                 rpc_client: MessageErrorRpcModule,
                 rpc_opts: [message: "execution reverted: SignatureValidator"]
               )
    end

    test "propagates non-revert RPC error messages" do
      hash = PersonalMessage.hash("other message")
      signature = sign_digest(hash, @other_private_key)

      assert {:error, %{"message" => "internal error"}} =
               Signature.verify_hash(hash, signature, @owner,
                 rpc_client: MessageErrorRpcModule,
                 rpc_opts: [message: "internal error"]
               )
    end

    test "rejects invalid hashes" do
      signature = sign_digest(PersonalMessage.hash("x"), @owner_private_key)

      assert {:error, :invalid_hash} = Signature.verify_hash(<<1, 2, 3>>, signature, @owner)
      assert {:error, :invalid_hash} = Signature.verify_hash("0x1234", signature, @owner)

      non_hex_hash = "0x" <> String.duplicate("zz", 32)
      assert {:error, :invalid_hash} = Signature.verify_hash(non_hex_hash, signature, @owner)
    end

    test "rejects non-hex-decodable signatures" do
      hash = PersonalMessage.hash("x")

      assert {:error, :invalid_signature} = Signature.verify_hash(hash, "0xzz", @owner)
    end

    test "rejects invalid addresses" do
      hash = PersonalMessage.hash("x")
      signature = sign_digest(hash, @owner_private_key)

      assert {:error, :invalid_address} = Signature.verify_hash(hash, signature, "0x1234")
    end
  end
end
