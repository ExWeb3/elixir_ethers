defmodule Ethers.TypedData.SchemaExpansionTest.Person do
  use Ethers.TypedData.Schema

  typed_schema "Person" do
    field(:name, :string)
    field(:wallet, :address)
  end
end

defmodule Ethers.TypedData.SchemaExpansionTest.Mail do
  use Ethers.TypedData.Schema

  alias Ethers.TypedData.SchemaExpansionTest.Person

  typed_schema "Mail" do
    field(:from, Person)
    field(:to, Person)
    field(:contents, :string)
  end
end

defmodule Ethers.TypedData.SchemaExpansionTest.Group do
  use Ethers.TypedData.Schema

  alias Ethers.TypedData.SchemaExpansionTest.Person

  typed_schema "Group" do
    field(:members, {:array, Person})
    field(:group_name, :string, name: "groupName")
  end
end

defmodule Ethers.TypedData.SchemaExpansionTest.Receipt do
  use Ethers.TypedData.Schema

  typed_schema "Receipt" do
    field(:payer, :address)
    field(:amount, :uint256)
    field(:ref, "bytes32")
    field(:memo, :string)
  end
end

defmodule Ethers.TypedData.SchemaExpansionTest.NotASchema do
  defstruct [:foo]
end

defmodule Ethers.TypedData.SchemaExpansionTest do
  use ExUnit.Case, async: true

  alias Ethers.TypedData
  alias Ethers.TypedData.SchemaExpansionTest.Group
  alias Ethers.TypedData.SchemaExpansionTest.Mail
  alias Ethers.TypedData.SchemaExpansionTest.NotASchema
  alias Ethers.TypedData.SchemaExpansionTest.Person
  alias Ethers.TypedData.SchemaExpansionTest.Receipt

  @cow_wallet "0xCD2a3d9F938E13CD947Ec05AbC7FE734Df8DD826"
  @bob_wallet "0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB"

  @domain [
    name: "Ether Mail",
    version: "1",
    chain_id: 1,
    verifying_contract: "0xCcCCccccCCCCcCCCCCCcCcCccCcCCCcCcccccccC"
  ]

  defp mail_struct do
    %Mail{
      from: %Person{name: "Cow", wallet: @cow_wallet},
      to: %Person{name: "Bob", wallet: @bob_wallet},
      contents: "Hello, Bob!"
    }
  end

  defp hand_built_mail do
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
      domain: @domain,
      message: %{
        "from" => %{"name" => "Cow", "wallet" => @cow_wallet},
        "to" => %{"name" => "Bob", "wallet" => @bob_wallet},
        "contents" => "Hello, Bob!"
      }
    )
  end

  describe "digest oracle (canonical Mail)" do
    test "struct-built Mail hashes to the EIP-712 spec digest" do
      td = TypedData.new!(mail_struct(), domain: @domain)

      assert TypedData.hash(td, :hex) ==
               "0xbe609aee343fb3c4b28e1df9e632fca64fcfaede20f02e86244efddf30957bd2"
    end

    test "struct-built Mail matches the hand-built TypedData across the engine" do
      struct_built = TypedData.new!(mail_struct(), domain: @domain)
      hand_built = hand_built_mail()

      assert TypedData.encode_type(struct_built, "Mail") ==
               TypedData.encode_type(hand_built, "Mail")

      assert TypedData.encode_type(struct_built, "Mail") ==
               "Mail(Person from,Person to,string contents)Person(string name,address wallet)"

      assert TypedData.domain_separator(struct_built) == TypedData.domain_separator(hand_built)
      assert TypedData.hash(struct_built) == TypedData.hash(hand_built)
      assert TypedData.to_eip712_json(struct_built) == TypedData.to_eip712_json(hand_built)
    end
  end

  describe "nested array of structs" do
    test "resolves {:array, Person} to Person[] and registers Person" do
      group = %Group{
        members: [
          %Person{name: "Cow", wallet: @cow_wallet},
          %Person{name: "Bob", wallet: @bob_wallet}
        ],
        group_name: "Farm"
      }

      td = TypedData.new!(group, domain: @domain)

      assert Map.has_key?(td.types, "Person")

      [members_field, _group_name_field] = td.types["Group"]
      assert members_field.type == "Person[]"

      hand_built =
        TypedData.new!(
          types: %{
            "Person" => [
              %{name: "name", type: "string"},
              %{name: "wallet", type: "address"}
            ],
            "Group" => [
              %{name: "members", type: "Person[]"},
              %{name: "groupName", type: "string"}
            ]
          },
          primary_type: "Group",
          domain: @domain,
          message: %{
            "members" => [
              %{"name" => "Cow", "wallet" => @cow_wallet},
              %{"name" => "Bob", "wallet" => @bob_wallet}
            ],
            "groupName" => "Farm"
          }
        )

      assert TypedData.hash(td) == TypedData.hash(hand_built)
    end
  end

  describe "atomic type variety" do
    test "resolves :address, :uint256, string \"bytes32\" and :string forms identically" do
      receipt = %Receipt{
        payer: @cow_wallet,
        amount: 1000,
        ref: "0x" <> String.duplicate("ab", 32),
        memo: "thanks"
      }

      td = TypedData.new!(receipt, domain: @domain)

      hand_built =
        TypedData.new!(
          types: %{
            "Receipt" => [
              %{name: "payer", type: "address"},
              %{name: "amount", type: "uint256"},
              %{name: "ref", type: "bytes32"},
              %{name: "memo", type: "string"}
            ]
          },
          primary_type: "Receipt",
          domain: @domain,
          message: %{
            "payer" => @cow_wallet,
            "amount" => 1000,
            "ref" => "0x" <> String.duplicate("ab", 32),
            "memo" => "thanks"
          }
        )

      assert Enum.map(td.types["Receipt"], & &1.type) ==
               ["address", "uint256", "bytes32", "string"]

      assert TypedData.hash(td) == TypedData.hash(hand_built)
    end
  end

  describe "new/2 and new!/2 entry points" do
    test "new/2 returns {:ok, td}" do
      assert {:ok, %TypedData{} = td} = TypedData.new(mail_struct(), domain: @domain)

      assert TypedData.hash(td, :hex) ==
               "0xbe609aee343fb3c4b28e1df9e632fca64fcfaede20f02e86244efddf30957bd2"
    end

    test "new/1 on a struct defaults the domain to empty" do
      assert {:ok, %TypedData{} = td} = TypedData.new(mail_struct())
      assert td.primary_type == "Mail"
    end

    test "new!/2 returns the struct" do
      assert %TypedData{} = TypedData.new!(mail_struct(), domain: @domain)
    end

    test "a non-schema struct passed to new/2 raises a clear error" do
      assert_raise ArgumentError, ~r/not an Ethers.TypedData schema/, fn ->
        TypedData.new(%NotASchema{foo: 1}, [])
      end
    end
  end
end
