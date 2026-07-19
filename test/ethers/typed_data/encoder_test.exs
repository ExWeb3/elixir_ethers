defmodule Ethers.TypedData.EncoderTest do
  use ExUnit.Case, async: true

  alias Ethers.TypedData
  alias Ethers.TypedData.Encoder
  alias Ethers.Utils

  doctest Ethers.TypedData.Encoder

  defp hex(bin), do: Utils.hex_encode(bin)

  describe "canonical EIP-712 Mail example" do
    # Vectors published in the EIP-712 specification (the Mail/Person example):
    # https://eips.ethereum.org/EIPS/eip-712 (see the "Specification of the Example" and the
    # reference implementation `assets/eip-712/Example.js`).
    setup do
      td =
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

      %{td: td}
    end

    test "encode_type/2 matches the spec", %{td: td} do
      assert Encoder.encode_type(td, "Mail") ==
               "Mail(Person from,Person to,string contents)Person(string name,address wallet)"

      assert Encoder.encode_type(td, "Person") == "Person(string name,address wallet)"
    end

    test "type_hash/2 matches the spec (full 32 bytes)", %{td: td} do
      type_hash = Encoder.type_hash(td, "Mail")
      assert byte_size(type_hash) == 32

      assert hex(type_hash) ==
               "0xa0cedeb2dc280ba39b857546d74f5549c3a1d7bdc2dd96bf881f76108e23dac2"
    end

    test "hash_struct/3 of the message matches the spec", %{td: td} do
      assert hex(Encoder.hash_struct(td, "Mail", td.message)) ==
               "0xc52c0ee5d84264471806290a3f2c4cecfc5490626bf912d01f240d7a274b371e"
    end

    test "domain_separator/1 matches the spec", %{td: td} do
      assert hex(Encoder.domain_separator(td)) ==
               "0xf2cee375fa42b42143804025fc449deafd50cc031ca257e0b194a650a912090f"
    end

    test "hash/1 (signing digest) matches the spec", %{td: td} do
      digest = Encoder.hash(td)
      assert byte_size(digest) == 32

      assert hex(digest) ==
               "0xbe609aee343fb3c4b28e1df9e632fca64fcfaede20f02e86244efddf30957bd2"

      # hash/2 hex output must agree with the binary form.
      assert Encoder.hash(td, :hex) == hex(digest)
      assert Encoder.hash(td, :bin) == digest
    end
  end

  describe "nested array-of-structs vector (ethers.js cross-check)" do
    # Independently produced with ethers.js v6.17.0 (`TypedDataEncoder`). This exercises an
    # array of structs (`Person[]`) and nested dynamic `address[]` arrays.
    #
    #   const typesA = {
    #     Person: [{name:"name",type:"string"}, {name:"wallets",type:"address[]"}],
    #     Mail: [{name:"from",type:"Person"}, {name:"to",type:"Person[]"}, {name:"contents",type:"string"}]
    #   };
    #   TypedDataEncoder.from(typesA).encodeType("Mail")
    #   TypedDataEncoder.from(typesA).hashStruct("Mail", valueA)
    #   TypedDataEncoder.hashDomain(domainA)
    #   TypedDataEncoder.hash(domainA, typesA, valueA)
    setup do
      td =
        TypedData.new!(
          types: %{
            "Person" => [
              %{name: "name", type: "string"},
              %{name: "wallets", type: "address[]"}
            ],
            "Mail" => [
              %{name: "from", type: "Person"},
              %{name: "to", type: "Person[]"},
              %{name: "contents", type: "string"}
            ]
          },
          primary_type: "Mail",
          domain: [
            name: "Ether Mail",
            version: "1",
            chain_id: 1,
            verifying_contract: "0xcccccccccccccccccccccccccccccccccccccccc"
          ],
          message: %{
            "from" => %{
              "name" => "Cow",
              "wallets" => [
                "0xcd2a3d9f938e13cd947ec05abc7fe734df8dd826",
                "0xdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef"
              ]
            },
            "to" => [
              %{
                "name" => "Bob",
                "wallets" => [
                  "0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
                  "0xb0b0b0b0b0b0b000000000000000000000000000"
                ]
              }
            ],
            "contents" => "Hello, Bob!"
          }
        )

      %{td: td}
    end

    test "encode_type/2", %{td: td} do
      assert Encoder.encode_type(td, "Mail") ==
               "Mail(Person from,Person[] to,string contents)Person(string name,address[] wallets)"
    end

    test "hash_struct/3", %{td: td} do
      assert hex(Encoder.hash_struct(td, "Mail", td.message)) ==
               "0xb1ae2bdff9f450cb829d4fea584e0407485af89480e6e1a6e493628bddfb106b"
    end

    test "domain_separator/1", %{td: td} do
      assert hex(Encoder.domain_separator(td)) ==
               "0xf2cee375fa42b42143804025fc449deafd50cc031ca257e0b194a650a912090f"
    end

    test "hash/1 digest", %{td: td} do
      assert Encoder.hash(td, :hex) ==
               "0xc26a267e7e449d3a8df39c1476d8e8f27216d86d49a9e1d3d096c9e64670c821"
    end
  end

  describe "mixed atomic types + partial domain vector (ethers.js cross-check)" do
    # Independently produced with ethers.js v6.17.0. Exercises a negative `int256`, dynamic
    # `bytes`, fixed `bytes32`, `string`, `uint8`, and a domain with only a subset of fields
    # present (`name` + `chainId`).
    #
    #   const domainB = { name: "Test", chainId: 5 };
    #   const typesB = { Order: [
    #     {name:"amount",type:"int256"}, {name:"data",type:"bytes"}, {name:"hash",type:"bytes32"},
    #     {name:"note",type:"string"}, {name:"count",type:"uint8"} ] };
    #   const valueB = { amount:"-12345", data:"0xdeadbeef",
    #     hash:"0x00000000000000000000000000000000000000000000000000000000000000ab",
    #     note:"hi", count:7 };
    setup do
      td =
        TypedData.new!(
          types: %{
            "Order" => [
              %{name: "amount", type: "int256"},
              %{name: "data", type: "bytes"},
              %{name: "hash", type: "bytes32"},
              %{name: "note", type: "string"},
              %{name: "count", type: "uint8"}
            ]
          },
          primary_type: "Order",
          domain: [name: "Test", chain_id: 5],
          message: %{
            "amount" => -12_345,
            "data" => "0xdeadbeef",
            "hash" => "0x00000000000000000000000000000000000000000000000000000000000000ab",
            "note" => "hi",
            "count" => 7
          }
        )

      %{td: td}
    end

    test "encode_type/2", %{td: td} do
      assert Encoder.encode_type(td, "Order") ==
               "Order(int256 amount,bytes data,bytes32 hash,string note,uint8 count)"
    end

    test "hash_struct/3 (negative int, dynamic bytes, bytes32)", %{td: td} do
      assert hex(Encoder.hash_struct(td, "Order", td.message)) ==
               "0xa3da230a39885569047b39e757b096a309aef43468f866292ea0c6ffebca3a5b"
    end

    test "domain_separator/1 with only a subset of domain fields present", %{td: td} do
      assert hex(Encoder.domain_separator(td)) ==
               "0x94773a93ac27b9c9c9e55543f5e5d81bf36a002890f81833375e3f5010b9505a"
    end

    test "hash/1 digest", %{td: td} do
      assert Encoder.hash(td, :hex) ==
               "0xbd5e3074d223a9171a21731fcff08c06ea194bc06749daae36849cf69c1a0731"
    end
  end

  describe "value-form equivalence" do
    # `address` and `bytesN` members must encode identically whether supplied as a `0x` hex string
    # or as a raw binary. Cross-checked structurally (the hex-string forms are already pinned to
    # ethers.js in the vectors above).
    test "address given as 20-byte binary equals the hex-string form" do
      raw_addr = Base.decode16!("b0b0b0b0b0b0b000000000000000000000000000", case: :lower)

      td_hex = order_td("0x00000000000000000000000000000000000000000000000000000000000000ab")
      td_bin = order_td(Base.decode16!(String.duplicate("0", 62) <> "ab", case: :lower))

      # bytes32 hex-string vs raw-binary equivalence
      assert Encoder.hash_struct(td_hex, "Thing", td_hex.message) ==
               Encoder.hash_struct(td_bin, "Thing", td_bin.message)

      # address hex-string vs raw-binary equivalence
      td_addr_hex = addr_td("0xb0b0b0b0b0b0b000000000000000000000000000")
      td_addr_bin = addr_td(raw_addr)

      assert Encoder.hash_struct(td_addr_hex, "Acct", td_addr_hex.message) ==
               Encoder.hash_struct(td_addr_bin, "Acct", td_addr_bin.message)
    end

    defp order_td(hash_value) do
      TypedData.new!(
        types: %{"Thing" => [%{name: "hash", type: "bytes32"}]},
        primary_type: "Thing",
        domain: [name: "T"],
        message: %{"hash" => hash_value}
      )
    end

    defp addr_td(addr_value) do
      TypedData.new!(
        types: %{"Acct" => [%{name: "owner", type: "address"}]},
        primary_type: "Acct",
        domain: [name: "T"],
        message: %{"owner" => addr_value}
      )
    end
  end
end
