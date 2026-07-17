defmodule Ethers.TypedDataTest do
  use ExUnit.Case

  doctest Ethers.TypedData
  doctest Ethers.TypedData.Domain
  doctest Ethers.TypedData.Field

  alias Ethers.TypedData
  alias Ethers.TypedData.Domain
  alias Ethers.TypedData.Field

  @mail_types %{
    "Person" => [
      %{name: "name", type: "string"},
      %{name: "wallet", type: "address"}
    ],
    "Mail" => [
      %{name: "from", type: "Person"},
      %{name: "to", type: "Person"},
      %{name: "contents", type: "string"}
    ]
  }

  @domain [
    name: "Ether Mail",
    version: "1",
    chain_id: 1,
    verifying_contract: "0xCcCCccccCCCCcCCCCCCcCcCccCcCCCcCcccccccC"
  ]

  @message %{
    "from" => %{"name" => "Cow", "wallet" => "0xCD2a3d9F938E13CD947Ec05AbC7FE734Df8DD826"},
    "to" => %{"name" => "Bob", "wallet" => "0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB"},
    "contents" => "Hello, Bob!"
  }

  describe "new/1" do
    test "builds the Mail/Person example and normalizes types to Field structs" do
      assert {:ok, typed_data} =
               TypedData.new(
                 types: @mail_types,
                 primary_type: "Mail",
                 domain: @domain,
                 message: @message
               )

      assert %TypedData{primary_type: "Mail"} = typed_data
      assert %Domain{name: "Ether Mail", chain_id: 1} = typed_data.domain

      assert typed_data.types["Person"] == [
               %Field{name: "name", type: "string"},
               %Field{name: "wallet", type: "address"}
             ]

      assert typed_data.types["Mail"] == [
               %Field{name: "from", type: "Person"},
               %Field{name: "to", type: "Person"},
               %Field{name: "contents", type: "string"}
             ]
    end

    test "accepts fields as maps with string keys and as Field structs" do
      types = %{
        "Person" => [
          %{"name" => "name", "type" => "string"},
          %Field{name: "wallet", type: "address"}
        ]
      }

      assert {:ok, typed_data} =
               TypedData.new(
                 types: types,
                 primary_type: "Person",
                 domain: %{},
                 message: %{"name" => "Cow"}
               )

      assert typed_data.types["Person"] == [
               %Field{name: "name", type: "string"},
               %Field{name: "wallet", type: "address"}
             ]
    end

    test "normalizes message atom keys to string keys" do
      assert {:ok, typed_data} =
               TypedData.new(
                 types: @mail_types,
                 primary_type: "Mail",
                 domain: @domain,
                 message: %{
                   from: %{name: "Cow", wallet: "0xCD2a3d9F938E13CD947Ec05AbC7FE734Df8DD826"},
                   contents: "Hello, Bob!"
                 }
               )

      assert typed_data.message == %{
               "from" => %{
                 "name" => "Cow",
                 "wallet" => "0xCD2a3d9F938E13CD947Ec05AbC7FE734Df8DD826"
               },
               "contents" => "Hello, Bob!"
             }
    end

    test "string message keys are preserved" do
      assert {:ok, typed_data} =
               TypedData.new(
                 types: @mail_types,
                 primary_type: "Mail",
                 domain: @domain,
                 message: @message
               )

      assert typed_data.message == @message
    end

    test "accepts a Domain struct for :domain" do
      domain = Domain.new(@domain)

      assert {:ok, typed_data} =
               TypedData.new(
                 types: @mail_types,
                 primary_type: "Mail",
                 domain: domain,
                 message: @message
               )

      assert typed_data.domain == domain
    end

    test "returns error when primary_type is not defined in types" do
      assert {:error, {:unknown_primary_type, "Ghost"}} =
               TypedData.new(
                 types: @mail_types,
                 primary_type: "Ghost",
                 domain: @domain,
                 message: @message
               )
    end

    test "returns error when a member references an undefined struct type" do
      types = %{
        "Mail" => [
          %{name: "from", type: "Person"},
          %{name: "contents", type: "string"}
        ]
      }

      assert {:error, {:undefined_type, "Person"}} =
               TypedData.new(
                 types: types,
                 primary_type: "Mail",
                 domain: @domain,
                 message: @message
               )
    end

    test "allows array member types referencing defined structs" do
      types = %{
        "Person" => [%{name: "name", type: "string"}],
        "Group" => [%{name: "members", type: "Person[]"}]
      }

      assert {:ok, _typed_data} =
               TypedData.new(
                 types: types,
                 primary_type: "Group",
                 domain: %{},
                 message: %{"members" => []}
               )
    end
  end

  describe "new!/1" do
    test "returns the struct on success" do
      assert %TypedData{primary_type: "Mail"} =
               TypedData.new!(
                 types: @mail_types,
                 primary_type: "Mail",
                 domain: @domain,
                 message: @message
               )
    end

    test "raises on unknown primary type" do
      assert_raise ArgumentError, ~r/unknown_primary_type/, fn ->
        TypedData.new!(
          types: @mail_types,
          primary_type: "Ghost",
          domain: @domain,
          message: @message
        )
      end
    end

    test "raises on undefined referenced type" do
      types = %{"Mail" => [%{name: "from", type: "Person"}]}

      assert_raise ArgumentError, ~r/undefined_type/, fn ->
        TypedData.new!(
          types: types,
          primary_type: "Mail",
          domain: @domain,
          message: %{}
        )
      end
    end
  end

  describe "Domain.new/1" do
    test "builds from a keyword list" do
      assert %Domain{
               name: "Ether Mail",
               version: "1",
               chain_id: 1,
               verifying_contract: "0xCcCCccccCCCCcCCCCCCcCcCccCcCCCcCcccccccC",
               salt: nil
             } = Domain.new(@domain)
    end

    test "builds from a map with atom and string keys" do
      assert %Domain{name: "A", chain_id: 5} = Domain.new(%{name: "A", chain_id: 5})
      assert %Domain{name: "A", chain_id: 5} = Domain.new(%{"name" => "A", "chain_id" => 5})
    end

    test "returns an existing Domain struct unchanged" do
      domain = Domain.new(@domain)
      assert Domain.new(domain) == domain
    end
  end

  describe "Domain.present_fields/1" do
    test "returns only non-nil fields in canonical order with solidity types" do
      domain =
        Domain.new(
          name: "Ether Mail",
          version: "1",
          chain_id: 1,
          verifying_contract: "0xCcCCccccCCCCcCCCCCCcCcCccCcCCCcCcccccccC"
        )

      assert Domain.present_fields(domain) == [
               %Field{name: "name", type: "string"},
               %Field{name: "version", type: "string"},
               %Field{name: "chainId", type: "uint256"},
               %Field{name: "verifyingContract", type: "address"}
             ]
    end

    test "includes salt as bytes32 and preserves canonical ordering" do
      domain = Domain.new(chain_id: 1, salt: <<0::256>>, name: "A")

      assert Domain.present_fields(domain) == [
               %Field{name: "name", type: "string"},
               %Field{name: "chainId", type: "uint256"},
               %Field{name: "salt", type: "bytes32"}
             ]
    end

    test "returns an empty list for an empty domain" do
      assert Domain.present_fields(Domain.new(%{})) == []
    end
  end
end
