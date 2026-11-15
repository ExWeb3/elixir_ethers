defmodule Ethers.TransactionValidationTest do
  use ExUnit.Case

  alias Ethers.Authorization
  alias Ethers.Signer
  alias Ethers.Transaction
  alias Ethers.Transaction.Eip1559
  alias Ethers.Transaction.Eip2930
  alias Ethers.Transaction.Eip4844
  alias Ethers.Transaction.Eip7702
  alias Ethers.Transaction.Legacy
  alias Ethers.Transaction.Signed
  alias Ethers.Utils

  @to "0x2222222222222222222222222222222222222222"

  # Anvil dev account #0
  @from "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
  @from_private_key "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"

  @access_list [
    [<<0x07A6E955BA4345BAE83AC2A6FAA771FDDD8A2011::160>>, [<<0::256>>, <<1::256>>]],
    [<<0x7D1AFA7B718FB893DB30A3ABC0CFC608AACFEBB0::160>>, []]
  ]

  @blob_versioned_hash Utils.hex_decode!(
                         "0x01bb9dc6ee48ae6a6f7ffd69a75196a4d49723beedf35981106e8da0efd8f796"
                       )

  @types [Legacy, Eip2930, Eip1559, Eip4844, Eip7702]
  @access_list_types [Eip2930, Eip1559, Eip4844, Eip7702]

  @required_fields %{
    Legacy => [nonce: :missing_nonce, gas_price: :missing_gas_price, gas: :missing_gas],
    Eip2930 => [
      chain_id: :missing_chain_id,
      nonce: :missing_nonce,
      gas_price: :missing_gas_price,
      gas: :missing_gas
    ],
    Eip1559 => [
      chain_id: :missing_chain_id,
      nonce: :missing_nonce,
      max_priority_fee_per_gas: :missing_max_priority_fee_per_gas,
      max_fee_per_gas: :missing_max_fee_per_gas,
      gas: :missing_gas
    ],
    Eip4844 => [
      chain_id: :missing_chain_id,
      nonce: :missing_nonce,
      max_priority_fee_per_gas: :missing_max_priority_fee_per_gas,
      max_fee_per_gas: :missing_max_fee_per_gas,
      gas: :missing_gas,
      to: :missing_to_address,
      max_fee_per_blob_gas: :missing_max_fee_per_blob_gas,
      blob_versioned_hashes: :empty_blob_versioned_hashes
    ],
    Eip7702 => [
      chain_id: :missing_chain_id,
      nonce: :missing_nonce,
      max_priority_fee_per_gas: :missing_max_priority_fee_per_gas,
      max_fee_per_gas: :missing_max_fee_per_gas,
      gas: :missing_gas,
      to: :missing_to_address,
      authorization_list: :empty_authorization_list
    ]
  }

  describe "new/1 with valid params" do
    test "builds every transaction type and the result encodes" do
      for type <- @types do
        assert {:ok, %^type{} = tx} = type.new(valid_params(type))
        assert is_binary(Transaction.encode(tx))
      end
    end
  end

  describe "new/1 required fields" do
    test "returns an error instead of raising for missing or nil required fields" do
      for {type, fields} <- @required_fields, {field, error} <- fields do
        params = valid_params(type)

        assert {:error, ^error} = type.new(Map.delete(params, field)),
               "expected #{inspect(type)}.new/1 without #{field} to return #{inspect(error)}"

        assert {:error, ^error} = type.new(Map.put(params, field, nil)),
               "expected #{inspect(type)}.new/1 with nil #{field} to return #{inspect(error)}"
      end
    end

    test "Transaction.new/1 returns an error for missing fields" do
      assert {:error, :missing_chain_id} = Transaction.new(%{type: Eip1559, nonce: 1})
      assert {:error, :missing_nonce} = Transaction.new(%{type: Legacy, gas_price: 1, gas: 1})
    end

    test "still rejects invalid values of required fields" do
      for {type, fields} <- @required_fields,
          {field, _error} <- fields,
          field not in [:to, :blob_versioned_hashes, :authorization_list] do
        assert {:error, :expected_non_neg_integer_value} =
                 type.new(Map.put(valid_params(type), field, -1))
      end
    end
  end

  describe "Legacy.new/1 chain_id (pre-EIP-155)" do
    test "accepts a missing or nil chain_id" do
      params = Map.delete(valid_params(Legacy), :chain_id)

      assert {:ok, %Legacy{chain_id: nil}} = Legacy.new(params)
      assert {:ok, %Legacy{chain_id: nil}} = Legacy.new(Map.put(params, :chain_id, nil))
      assert {:ok, %Legacy{chain_id: nil}} = Transaction.new(Map.put(params, :type, Legacy))
    end

    test "a transaction without chain_id is hashed without the EIP-155 fields" do
      {:ok, tx} = Legacy.new(Map.delete(valid_params(Legacy), :chain_id))

      assert Transaction.encode(tx) ==
               ExRLP.encode([1, 10, 21_000, Utils.decode_address!(@to), 0, ""])
    end

    test "still validates a given chain_id" do
      assert {:error, :expected_non_neg_integer_value} =
               Legacy.new(Map.put(valid_params(Legacy), :chain_id, -1))

      assert {:error, :expected_non_neg_integer_value} =
               Legacy.new(Map.put(valid_params(Legacy), :chain_id, "0x1"))
    end
  end

  describe "from_rpc_map/1 with pre-EIP-155 legacy transactions" do
    test "returns the transaction (issue reproduction)" do
      tx_map = %{
        "type" => "0x0",
        "nonce" => "0x0",
        "gas" => "0x5208",
        "gasPrice" => "0x1",
        "to" => @to,
        "value" => "0x1",
        "input" => "0x",
        "v" => "0x1b",
        "r" => "0x1",
        "s" => "0x1"
      }

      assert {:ok,
              %Signed{
                payload: %Legacy{chain_id: nil, nonce: 0, gas: 21_000, gas_price: 1, value: 1},
                signature_y_parity_or_v: 27
              }} = Transaction.from_rpc_map(tx_map)
    end

    test "returns a transaction that re-encodes to the signed raw transaction" do
      {:ok, unsigned} = Legacy.new(Map.delete(valid_params(Legacy), :chain_id))

      {:ok, raw_tx} =
        Signer.Local.sign_transaction(unsigned, private_key: @from_private_key)

      {:ok, %Signed{signature_y_parity_or_v: v} = signed} = Transaction.decode(raw_tx)
      assert v in [27, 28]

      tx_map = %{
        "type" => "0x0",
        "hash" => Transaction.transaction_hash(signed),
        "from" => @from,
        "nonce" => Utils.integer_to_hex(unsigned.nonce),
        "gas" => Utils.integer_to_hex(unsigned.gas),
        "gasPrice" => Utils.integer_to_hex(unsigned.gas_price),
        "to" => @to,
        "value" => Utils.integer_to_hex(unsigned.value),
        "input" => "0x",
        "v" => Utils.integer_to_hex(v),
        "r" => Utils.hex_encode(signed.signature_r),
        "s" => Utils.hex_encode(signed.signature_s)
      }

      assert {:ok, %Signed{payload: %Legacy{chain_id: nil}} = fetched} =
               Transaction.from_rpc_map(tx_map)

      assert Utils.hex_encode(Transaction.encode(fetched)) == raw_tx
      assert Transaction.transaction_hash(fetched) == tx_map["hash"]
    end
  end

  describe "send path" do
    test "legacy transactions sent with a signer still get an auto-filled chain_id" do
      {:ok, raw_tx} =
        Ethers.sign_transaction(%{value: 1},
          from: @from,
          to: @to,
          type: Legacy,
          signer: Signer.Local,
          signer_opts: [private_key: @from_private_key]
        )

      {:ok, chain_id} = Ethers.chain_id()

      assert {:ok, %Signed{payload: %Legacy{}, signature_y_parity_or_v: v}} =
               Transaction.decode(raw_tx)

      # EIP-155: v = recovery_id + chain_id * 2 + 35
      assert v in [chain_id * 2 + 35, chain_id * 2 + 36]
    end
  end

  describe "new/1 to address" do
    test "Eip1559 validates to like every other type" do
      params = valid_params(Eip1559)

      assert {:error, :invalid_address_length} = Eip1559.new(%{params | to: "0x1234"})
      assert {:error, :invalid_address} = Eip1559.new(%{params | to: "not an address"})

      assert {:error, :invalid_address_length} =
               Transaction.new(%{
                 type: Eip1559,
                 chain_id: 1,
                 nonce: 1,
                 max_fee_per_gas: 10,
                 max_priority_fee_per_gas: 1,
                 gas: 21_000,
                 to: "0x1234"
               })
    end

    test "every type rejects malformed to addresses" do
      for type <- @types do
        params = valid_params(type)

        assert {:error, :invalid_address_length} = type.new(%{params | to: "0x1234"})
        assert {:error, :invalid_address} = type.new(%{params | to: Utils.decode_address!(@to)})
      end
    end

    test "contract creation (nil to) is allowed only where the EIP allows it" do
      for type <- [Legacy, Eip2930, Eip1559] do
        assert {:ok, %{to: nil}} = type.new(Map.delete(valid_params(type), :to))
      end

      for type <- [Eip4844, Eip7702] do
        assert {:error, :missing_to_address} = type.new(Map.delete(valid_params(type), :to))
      end
    end
  end

  describe "Eip4844.new/1 blob_versioned_hashes" do
    test "requires at least one versioned hash" do
      params = valid_params(Eip4844)

      assert {:error, :empty_blob_versioned_hashes} =
               Eip4844.new(%{params | blob_versioned_hashes: []})
    end

    test "requires each versioned hash to be a 32-byte binary" do
      params = valid_params(Eip4844)

      for invalid <- [
            [<<1::248>>],
            [@blob_versioned_hash <> <<0>>],
            [Utils.hex_encode(@blob_versioned_hash)],
            [@blob_versioned_hash, 1],
            @blob_versioned_hash
          ] do
        assert {:error, :invalid_blob_versioned_hashes} =
                 Eip4844.new(%{params | blob_versioned_hashes: invalid})
      end
    end

    test "accepts multiple versioned hashes" do
      hashes = [@blob_versioned_hash, <<1, 0::248>>]

      assert {:ok, %Eip4844{blob_versioned_hashes: ^hashes}} =
               Eip4844.new(%{valid_params(Eip4844) | blob_versioned_hashes: hashes})
    end
  end

  describe "new/1 access_list" do
    test "accepts a valid, empty or omitted access list" do
      for type <- @access_list_types do
        params = valid_params(type)

        assert {:ok, %{access_list: @access_list}} = type.new(params)
        assert {:ok, %{access_list: []}} = type.new(%{params | access_list: []})
        assert {:ok, %{access_list: []}} = type.new(%{params | access_list: nil})
        assert {:ok, %{access_list: []}} = type.new(Map.delete(params, :access_list))
      end
    end

    test "rejects wrongly shaped access lists" do
      address = <<0x07A6E955BA4345BAE83AC2A6FAA771FDDD8A2011::160>>
      key = <<1::256>>

      invalid_access_lists = [
        # address as a 0x string
        [[Utils.encode_address!(address), [key]]],
        # address too short
        [[<<1::152>>, [key]]],
        # storage key not 32 bytes
        [[address, [<<1::248>>]]],
        # storage key as a 0x string
        [[address, [Utils.hex_encode(key)]]],
        # storage keys not a list
        [[address, key]],
        # wrong nesting
        [address, [key]],
        [[address, [key], []]],
        # tuple entry
        [{address, [key]}],
        # RPC-style map entry
        [
          %{"address" => Utils.encode_address!(address), "storageKeys" => [Utils.hex_encode(key)]}
        ],
        # not a list
        %{}
      ]

      for type <- @access_list_types, invalid <- invalid_access_lists do
        assert {:error, :invalid_access_list} =
                 type.new(%{valid_params(type) | access_list: invalid}),
               "expected #{inspect(type)}.new/1 to reject access list #{inspect(invalid)}"
      end
    end
  end

  describe "Eip7702.new/1 authorization_list" do
    test "restricts signature_y_parity to 0 or 1" do
      for y_parity <- [0, 1] do
        authorization = %{signed_authorization() | signature_y_parity: y_parity}

        assert {:ok, %Eip7702{}} =
                 Eip7702.new(%{valid_params(Eip7702) | authorization_list: [authorization]})
      end

      for y_parity <- [2, 27, 28, -1, nil, "0x0"] do
        authorization = %{signed_authorization() | signature_y_parity: y_parity}

        assert {:error, :invalid_signature_y_parity} =
                 Eip7702.new(%{
                   valid_params(Eip7702)
                   | authorization_list: [signed_authorization(), authorization]
                 })
      end
    end

    test "bounds the authorization chain_id to less than 2**256" do
      max_chain_id = %{authorization() | chain_id: 2 ** 256 - 1}
      too_large_chain_id = %{authorization() | chain_id: 2 ** 256}

      assert {:ok, %Eip7702{}} =
               Eip7702.new(%{
                 valid_params(Eip7702)
                 | authorization_list: [%{signed_authorization() | authorization: max_chain_id}]
               })

      assert {:error, :chain_id_out_of_range} =
               Eip7702.new(%{
                 valid_params(Eip7702)
                 | authorization_list: [
                     %{signed_authorization() | authorization: too_large_chain_id}
                   ]
               })
    end

    test "validates the authorization tuple like Authorization.new/1" do
      invalid_authorizations = [
        {%{authorization() | nonce: 2 ** 64}, :nonce_out_of_range},
        {%{authorization() | chain_id: -1}, :expected_non_neg_integer_value},
        {%{authorization() | address: "0x1234"}, :invalid_address_length},
        {%{authorization() | address: nil}, :missing_address}
      ]

      for {authorization, error} <- invalid_authorizations do
        signed = %{signed_authorization() | authorization: authorization}

        assert {:error, ^error} =
                 Eip7702.new(%{valid_params(Eip7702) | authorization_list: [signed]})
      end
    end

    test "requires binary signature values" do
      for field <- [:signature_r, :signature_s] do
        signed = Map.put(signed_authorization(), field, 1)

        assert {:error, :expected_binary_value} =
                 Eip7702.new(%{valid_params(Eip7702) | authorization_list: [signed]})
      end
    end

    test "rejects entries that are not signed authorizations" do
      for invalid <- [authorization(), %{signed_authorization() | authorization: %{}}, nil] do
        assert {:error, :invalid_authorization_list} =
                 Eip7702.new(%{valid_params(Eip7702) | authorization_list: [invalid]})
      end
    end
  end

  defp valid_params(Legacy) do
    %{chain_id: 1, nonce: 1, gas_price: 10, gas: 21_000, to: @to}
  end

  defp valid_params(Eip2930) do
    %{chain_id: 1, nonce: 1, gas_price: 10, gas: 21_000, to: @to, access_list: @access_list}
  end

  defp valid_params(Eip1559) do
    %{
      chain_id: 1,
      nonce: 1,
      max_priority_fee_per_gas: 1,
      max_fee_per_gas: 10,
      gas: 21_000,
      to: @to,
      access_list: @access_list
    }
  end

  defp valid_params(Eip4844) do
    Eip1559
    |> valid_params()
    |> Map.merge(%{max_fee_per_blob_gas: 1, blob_versioned_hashes: [@blob_versioned_hash]})
  end

  defp valid_params(Eip7702) do
    Eip1559
    |> valid_params()
    |> Map.put(:authorization_list, [signed_authorization()])
  end

  defp authorization do
    Authorization.new!(chain_id: 1, address: @to, nonce: 0)
  end

  defp signed_authorization do
    %Authorization.Signed{
      authorization: authorization(),
      signature_y_parity: 0,
      signature_r: <<1::256>>,
      signature_s: <<2::256>>
    }
  end
end
