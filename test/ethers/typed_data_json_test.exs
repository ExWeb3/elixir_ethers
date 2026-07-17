defmodule Ethers.TypedDataJsonTest do
  use ExUnit.Case, async: true

  alias Ethers.TypedData

  describe "to_eip712_json/1" do
    test "produces the canonical EIP-712 Mail example map" do
      typed_data =
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

      expected = %{
        "types" => %{
          "EIP712Domain" => [
            %{"name" => "name", "type" => "string"},
            %{"name" => "version", "type" => "string"},
            %{"name" => "chainId", "type" => "uint256"},
            %{"name" => "verifyingContract", "type" => "address"}
          ],
          "Person" => [
            %{"name" => "name", "type" => "string"},
            %{"name" => "wallet", "type" => "address"}
          ],
          "Mail" => [
            %{"name" => "from", "type" => "Person"},
            %{"name" => "to", "type" => "Person"},
            %{"name" => "contents", "type" => "string"}
          ]
        },
        "primaryType" => "Mail",
        "domain" => %{
          "name" => "Ether Mail",
          "version" => "1",
          "chainId" => "1",
          "verifyingContract" => "0xCcCCccccCCCCcCCCCCCcCcCccCcCCCcCcccccccC"
        },
        "message" => %{
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
      }

      assert TypedData.to_eip712_json(typed_data) == expected
    end

    test "nested message structs become nested maps" do
      json = TypedData.to_eip712_json(mail_example())

      assert %{"message" => %{"from" => from, "to" => to}} = json
      assert is_map(from)
      assert is_map(to)
      assert from["name"] == "Cow"
      assert to["name"] == "Bob"
    end

    test "chainId is serialized as a decimal string" do
      json = TypedData.to_eip712_json(mail_example())

      assert json["domain"]["chainId"] == "1"
    end

    test "addresses are checksummed hex" do
      json = TypedData.to_eip712_json(mail_example())

      assert json["message"]["from"]["wallet"] ==
               "0xCD2a3d9F938E13CD947Ec05AbC7FE734Df8DD826"
    end

    test "only present domain fields appear (no salt)" do
      json = TypedData.to_eip712_json(mail_example())

      refute Map.has_key?(json["domain"], "salt")
      refute Enum.any?(json["types"]["EIP712Domain"], &(&1["name"] == "salt"))
    end

    test "accepts integer, decimal string and hex string integers" do
      typed_data =
        TypedData.new!(
          types: %{
            "Amounts" => [
              %{name: "a", type: "uint256"},
              %{name: "b", type: "uint256"},
              %{name: "c", type: "int128"}
            ]
          },
          primary_type: "Amounts",
          domain: [name: "x"],
          message: %{"a" => 42, "b" => "1000000", "c" => "0xff"}
        )

      assert %{"message" => %{"a" => "42", "b" => "1000000", "c" => "255"}} =
               TypedData.to_eip712_json(typed_data)
    end

    test "serializes bytes and bytesN as 0x hex, accepting binaries and hex strings" do
      typed_data =
        TypedData.new!(
          types: %{
            "Blob" => [
              %{name: "fixed", type: "bytes32"},
              %{name: "dynamic", type: "bytes"}
            ]
          },
          primary_type: "Blob",
          domain: [name: "x"],
          message: %{
            "fixed" => <<0::256>>,
            "dynamic" => "0xdeadbeef"
          }
        )

      json = TypedData.to_eip712_json(typed_data)
      assert json["message"]["fixed"] == "0x" <> String.duplicate("00", 32)
      assert json["message"]["dynamic"] == "0xdeadbeef"
    end

    test "serializes arrays element by element, including nested arrays" do
      typed_data =
        TypedData.new!(
          types: %{
            "Data" => [
              %{name: "flat", type: "uint256[]"},
              %{name: "nested", type: "uint256[][]"},
              %{name: "people", type: "Person[]"}
            ],
            "Person" => [
              %{name: "name", type: "string"},
              %{name: "wallet", type: "address"}
            ]
          },
          primary_type: "Data",
          domain: [name: "x"],
          message: %{
            "flat" => [1, 2, 3],
            "nested" => [[1, 2], [3]],
            "people" => [
              %{"name" => "Cow", "wallet" => "0xCD2a3d9F938E13CD947Ec05AbC7FE734Df8DD826"}
            ]
          }
        )

      json = TypedData.to_eip712_json(typed_data)
      assert json["message"]["flat"] == ["1", "2", "3"]
      assert json["message"]["nested"] == [["1", "2"], ["3"]]

      assert json["message"]["people"] == [
               %{"name" => "Cow", "wallet" => "0xCD2a3d9F938E13CD947Ec05AbC7FE734Df8DD826"}
             ]
    end

    test "output is JSON-encodable with Jason" do
      assert {:ok, _json_string} =
               mail_example() |> TypedData.to_eip712_json() |> Jason.encode()
    end
  end

  defp mail_example do
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
end
