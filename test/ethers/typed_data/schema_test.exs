defmodule Ethers.TypedData.SchemaTest.Person do
  use Ethers.TypedData.Schema

  typed_schema "Person" do
    field(:name, :string)
    field(:wallet, :address)
  end
end

defmodule Ethers.TypedData.SchemaTest.Mail do
  use Ethers.TypedData.Schema

  alias Ethers.TypedData.SchemaTest.Person

  typed_schema "Mail" do
    field(:from, Person)
    field(:to, Person)
    field(:contents, :string, default: "Hello")
  end
end

defmodule Ethers.TypedData.SchemaTest.Group do
  use Ethers.TypedData.Schema

  alias Ethers.TypedData.SchemaTest.Person

  # No explicit type name -> derived from the module's last segment ("Group").
  typed_schema do
    field(:members, {:array, Person})
    field(:group_name, :string, name: "groupName")
    field(:count, :uint256, default: 0)
  end
end

defmodule Ethers.TypedData.SchemaTest do
  use ExUnit.Case, async: true

  doctest Ethers.TypedData.Schema

  alias Ethers.TypedData.SchemaTest.Group
  alias Ethers.TypedData.SchemaTest.Mail
  alias Ethers.TypedData.SchemaTest.Person

  describe "generated struct" do
    test "has the declared keys with nil defaults" do
      mail = %Mail{}

      assert Map.has_key?(mail, :from)
      assert Map.has_key?(mail, :to)
      assert Map.has_key?(mail, :contents)

      assert mail.from == nil
      assert mail.to == nil
    end

    test "applies field :default values" do
      assert %Mail{}.contents == "Hello"
      assert %Group{}.count == 0
      assert %Group{}.members == nil
      assert %Group{}.group_name == nil
    end
  end

  describe "__typed_data_schema__/0" do
    test "returns the explicit type name and ordered field metadata" do
      assert Person.__typed_data_schema__() ==
               {"Person",
                [
                  %{key: :name, name: "name", type: :string},
                  %{key: :wallet, name: "wallet", type: :address}
                ]}
    end

    test "preserves field declaration order and raw module type terms" do
      {name, fields} = Mail.__typed_data_schema__()

      assert name == "Mail"

      assert fields == [
               %{key: :from, name: "from", type: Person},
               %{key: :to, name: "to", type: Person},
               %{key: :contents, name: "contents", type: :string}
             ]

      # Order is significant (EIP-712 encodeType).
      assert Enum.map(fields, & &1.key) == [:from, :to, :contents]

      # :default is dropped from the introspection tuple.
      refute Enum.any?(fields, &Map.has_key?(&1, :default))
    end

    test "defaults the type name to the module's last segment" do
      {name, _fields} = Group.__typed_data_schema__()

      assert name == "Group"
    end

    test "honors :name overrides and raw array/atom type terms" do
      {_name, fields} = Group.__typed_data_schema__()

      assert fields == [
               %{key: :members, name: "members", type: {:array, Person}},
               %{key: :group_name, name: "groupName", type: :string},
               %{key: :count, name: "count", type: :uint256}
             ]
    end
  end

  describe "compile-time guard rails" do
    test "raises on duplicate field keys" do
      assert_raise ArgumentError, ~r/:name is already declared/, fn ->
        Code.eval_string("""
        defmodule Ethers.TypedData.SchemaTest.Dup do
          use Ethers.TypedData.Schema

          typed_schema "Dup" do
            field(:name, :string)
            field(:name, :address)
          end
        end
        """)
      end
    end

    test "raises when no field is declared" do
      assert_raise ArgumentError, ~r/must declare at least one field/, fn ->
        Code.eval_string("""
        defmodule Ethers.TypedData.SchemaTest.Empty do
          use Ethers.TypedData.Schema

          typed_schema "Empty" do
          end
        end
        """)
      end
    end

    test "raises when field key is not an atom" do
      assert_raise ArgumentError, ~r/field key must be an atom/, fn ->
        Code.eval_string("""
        defmodule Ethers.TypedData.SchemaTest.BadKey do
          use Ethers.TypedData.Schema

          typed_schema "BadKey" do
            field("name", :string)
          end
        end
        """)
      end
    end
  end
end
