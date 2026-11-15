defmodule Ethers.Signer.JsonRPCTest.AccountsRPC do
  @moduledoc false

  def request("eth_accounts", [], opts) do
    case Keyword.fetch(opts, :error) do
      {:ok, reason} -> {:error, reason}
      :error -> {:ok, Keyword.fetch!(opts, :accounts)}
    end
  end
end

defmodule Ethers.Signer.JsonRPCTest do
  use ExUnit.Case

  alias Ethers.Signer
  alias Ethers.Signer.JsonRPCTest.AccountsRPC
  alias Ethers.Utils

  describe "sign_transaction/2" do
    test "signs the transaction with the correct data" do
      transaction = %Ethers.Transaction.Eip1559{
        to: "0xFFcf8FDEE72ac11b5c542428B35EEF5769C409f0",
        input: Utils.hex_decode!("0x06fdde03"),
        value: 0,
        chain_id: 31_337,
        nonce: 2918,
        gas: 23_170,
        max_fee_per_gas: 87_119_557_365,
        max_priority_fee_per_gas: 0
      }

      assert {:ok,
              "0x02f86f827a69820b6680851448baf2f5825a8294ffcf8fdee72ac11b5c542428b35eef5769c409f0808406fdde03c080a03d39a64cec141391314296113f494c750619792b845966975d5f9862307edd83a06027e4f44dceae37b773933587e68e5b3174cd490ba0e2f0628dc33eb5f53f97"} ==
               Signer.JsonRPC.sign_transaction(transaction, [])
    end

    test "fails signing transaction with wrong from address" do
      transaction = %Ethers.Transaction.Eip1559{
        to: "0xFFcf8FDEE72ac11b5c542428B35EEF5769C409f0",
        input: Utils.hex_decode!("0x06fdde03"),
        value: 0,
        chain_id: 31_337,
        nonce: 2918,
        gas: 23_170,
        max_fee_per_gas: 87_119_557_365,
        max_priority_fee_per_gas: 0
      }

      assert {:error, error} =
               Signer.JsonRPC.sign_transaction(transaction,
                 from: "0xbba94ef8bd5ffee41947b4585a84bda5a3d3da6e"
               )

      assert error["message"] =~ "No Signer available"
    end
  end

  describe "sign_typed_data/2" do
    test "returns a well-formed 65-byte signature for the default account" do
      typed_data =
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
            chain_id: 31_337,
            verifying_contract: "0xCcCCccccCCCCcCCCCCCcCcCccCcCCCcCcccccccC"
          ],
          message: %{
            "from" => %{
              "name" => "Cow",
              "wallet" => "0xCD2a3d9F938E13CD947Ec05AbC7FE734Df8DD826"
            },
            "to" => %{
              "name" => "Bob",
              "wallet" => "0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB"
            },
            "contents" => "Hello, Bob!"
          }
        )

      assert {:ok, signature} =
               Signer.JsonRPC.sign_typed_data(typed_data,
                 from: "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266"
               )

      assert <<"0x", hex::binary-size(130)>> = signature
      assert String.match?(hex, ~r/^[0-9a-fA-F]{130}$/)
    end

    test "fails signing with an unknown from address" do
      typed_data =
        Ethers.TypedData.new!(
          types: %{
            "Mail" => [%{name: "contents", type: "string"}]
          },
          primary_type: "Mail",
          domain: [name: "Ether Mail", version: "1", chain_id: 31_337],
          message: %{"contents" => "Hello, Bob!"}
        )

      assert {:error, _reason} =
               Signer.JsonRPC.sign_typed_data(typed_data,
                 from: "0xbba94ef8bd5ffee41947b4585a84bda5a3d3da6e"
               )
    end

    test "returns an error tuple (not a raise) when :from is missing" do
      typed_data =
        Ethers.TypedData.new!(
          types: %{"Mail" => [%{name: "contents", type: "string"}]},
          primary_type: "Mail",
          domain: [name: "Ether Mail", version: "1", chain_id: 31_337],
          message: %{"contents" => "Hello, Bob!"}
        )

      assert {:error, :missing_from_address} = Signer.JsonRPC.sign_typed_data(typed_data, [])
    end
  end

  describe "personal_sign/2" do
    test "signs a message for the default account (verified via recovery)" do
      from = "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266"
      message = "sign in to example.com"

      assert {:ok, signature} = Signer.JsonRPC.personal_sign(message, from: from)

      assert <<"0x", hex::binary-size(130)>> = signature
      assert String.match?(hex, ~r/^[0-9a-fA-F]{130}$/)
      assert Ethers.PersonalMessage.verify(message, signature, from)
    end

    test "fails signing with an unknown from address" do
      assert {:error, _reason} =
               Signer.JsonRPC.personal_sign("Hello world",
                 from: "0xbba94ef8bd5ffee41947b4585a84bda5a3d3da6e"
               )
    end

    test "returns an error tuple (not a raise) when :from is missing" do
      assert {:error, :missing_from_address} = Signer.JsonRPC.personal_sign("Hello world", [])
    end
  end

  describe "accounts/1" do
    test "returns account list" do
      assert {:ok, accounts} = Signer.JsonRPC.accounts([])

      # anvil reports the accounts in lowercase
      assert accounts == [
               "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
               "0x70997970C51812dc3A010C7d01b50e0d17dc79C8",
               "0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC",
               "0x90F79bf6EB2c4f870365E785982E1f101E93b906",
               "0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65",
               "0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc",
               "0x976EA74026E726554dB657fA54763abd0C3a0aa9",
               "0x14dC79964da2C08b23698B3D3cc7Ca32193d9955",
               "0x23618e81E3f5cdF7f54C3d65f7FBc0aBf5B21E8f",
               "0xa0Ee7A142d267C1f36714E4a8F75612F20a79720"
             ]
    end

    test "checksums the accounts and keeps malformed values as returned" do
      opts = [
        rpc_module: AccountsRPC,
        accounts: [
          "0xF39FD6E51AAD88F6F4CE6AB8827279CFFFB92266",
          "0x70997970C51812dc3A010C7d01b50e0d17dc79C8",
          "0x1234",
          nil
        ]
      ]

      assert {:ok,
              [
                "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
                "0x70997970C51812dc3A010C7d01b50e0d17dc79C8",
                "0x1234",
                nil
              ]} == Signer.JsonRPC.accounts(opts)
    end

    test "returns RPC errors untouched" do
      assert {:error, :boom} ==
               Signer.JsonRPC.accounts(rpc_module: AccountsRPC, error: :boom)
    end
  end
end
