defmodule Ethers.SiweVerifyTest.RaisingRpcModule do
  @moduledoc false
  # Used to prove code paths that must not hit the network.

  def eth_call(_params, _block, _opts) do
    raise "eth_call must not be called in this code path"
  end
end

defmodule Ethers.SiweVerifyTest.ErrorRpcModule do
  @moduledoc false
  # Simulates an RPC transport failure.

  def eth_call(_params, _block, _opts), do: {:error, :nxdomain}
end

defmodule Ethers.Contract.Test.SiweERC1271WalletContract do
  @moduledoc false
  use Ethers.Contract, abi_file: "tmp/erc1271_wallet_abi.json"
end

defmodule Ethers.SiweVerifyTest do
  use ExUnit.Case

  import Ethers.TestHelpers

  alias Ethers.Contract.Test.SiweERC1271WalletContract
  alias Ethers.Siwe
  alias Ethers.Siwe.Message
  alias Ethers.SiweVerifyTest.ErrorRpcModule
  alias Ethers.SiweVerifyTest.RaisingRpcModule

  # 0x90F8bf6A479f320ead074411a4B0e7944Ea8c9C1 (same key used across the suite)
  @owner_private_key "0x4f3edf983ac636a65a842ce7c78d9aa706d3b113bce9c46f30d7d21715b23b1d"
  @owner "0x90F8bf6A479f320ead074411a4B0e7944Ea8c9C1"
  # First anvil dev account (funded, unlocked) — used to send deployment transactions
  @from "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
  @other_private_key "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"

  defp build_message(overrides \\ []) do
    Siwe.new!(
      Keyword.merge(
        [
          domain: "example.com",
          address: @owner,
          statement: "Sign in to Example",
          uri: "https://example.com/login",
          chain_id: 1,
          nonce: "32891756",
          issued_at: "2021-09-30T16:25:24.000Z"
        ],
        overrides
      )
    )
  end

  defp sign(raw_message, private_key) do
    Ethers.personal_sign!(raw_message,
      signer: Ethers.Signer.Local,
      signer_opts: [private_key: private_key]
    )
  end

  describe "verify/3 with EOA signatures" do
    test "verifies a raw message string without any RPC call" do
      raw = Siwe.to_message(build_message())
      signature = sign(raw, @owner_private_key)

      assert {:ok, %Message{address: @owner, domain: "example.com"}} =
               Siwe.verify(raw, signature,
                 domain: "example.com",
                 nonce: "32891756",
                 rpc_client: RaisingRpcModule
               )
    end

    test "verifies an already-parsed message struct" do
      message = build_message()
      signature = sign(Siwe.to_message(message), @owner_private_key)

      assert {:ok, ^message} = Siwe.verify(message, signature, rpc_client: RaisingRpcModule)
    end

    test "rejects a signature by a different key" do
      raw = Siwe.to_message(build_message())
      signature = sign(raw, @other_private_key)

      assert {:error, :invalid_signature} = Siwe.verify(raw, signature)
    end

    test "rejects a signature over a different message" do
      raw = Siwe.to_message(build_message())
      signature = sign("something else entirely", @owner_private_key)

      assert {:error, :invalid_signature} = Siwe.verify(raw, signature)
    end
  end

  describe "verify/3 validation errors" do
    test "propagates field validation errors before checking the signature" do
      message = build_message(expiration_time: "2021-09-30T17:00:00Z")
      raw = Siwe.to_message(message)
      signature = sign(raw, @owner_private_key)

      # rpc_client would raise if the signature check ran — validation fails first
      assert {:error, :expired} =
               Siwe.verify(raw, signature,
                 time: ~U[2022-01-01 00:00:00Z],
                 rpc_client: RaisingRpcModule
               )

      assert {:error, :domain_mismatch} =
               Siwe.verify(raw, signature,
                 domain: "evil.com",
                 time: ~U[2021-09-30 16:30:00Z],
                 rpc_client: RaisingRpcModule
               )

      assert {:error, :nonce_mismatch} =
               Siwe.verify(raw, signature,
                 nonce: "deadbeef",
                 time: ~U[2021-09-30 16:30:00Z],
                 rpc_client: RaisingRpcModule
               )
    end

    test "propagates parse errors" do
      assert {:error, :invalid_message_format} = Siwe.verify("not a siwe message", "0x1234")
    end

    test "propagates RPC transport errors from the signature check" do
      raw = Siwe.to_message(build_message())
      signature = sign(raw, @other_private_key)

      assert {:error, :nxdomain} = Siwe.verify(raw, signature, rpc_client: ErrorRpcModule)
    end
  end

  describe "verify/3 with a smart-contract wallet (ERC-1271)" do
    test "verifies a wallet-owner signature against the wallet address" do
      encoded_constructor = SiweERC1271WalletContract.constructor(@owner)

      wallet =
        deploy(SiweERC1271WalletContract, encoded_constructor: encoded_constructor, from: @from)

      raw = Siwe.to_message(build_message(address: wallet))
      owner_signature = sign(raw, @owner_private_key)
      other_signature = sign(raw, @other_private_key)

      assert {:ok, %Message{address: address}} = Siwe.verify(raw, owner_signature)
      assert String.downcase(address) == String.downcase(wallet)

      assert {:error, :invalid_signature} = Siwe.verify(raw, other_signature)
    end
  end
end
