defmodule Ethers.UtilsTest do
  use ExUnit.Case
  alias Ethers.Utils
  doctest Ethers.Utils

  describe "get_block_timestamp" do
    test "returns the block timestamp" do
      assert {:ok, n} = Ethers.current_block_number()
      assert {:ok, t} = Utils.get_block_timestamp(n)
      assert abs(System.system_time(:second) - t) < 100
    end

    test "can override the rpc opts" do
      assert {:ok, 500} =
               Utils.get_block_timestamp(100,
                 rpc_client: Ethers.TestRPCModule,
                 rpc_opts: [timestamp: 400]
               )
    end
  end

  describe "date_to_block_number" do
    test "calculates the right block number for a given date" do
      assert {:ok, n} = Ethers.current_block_number()
      assert {:ok, ^n} = Utils.date_to_block_number(DateTime.utc_now())
      assert {:ok, ^n} = Utils.date_to_block_number(DateTime.utc_now(), n)
      assert {:ok, ^n} = Utils.date_to_block_number(DateTime.utc_now() |> DateTime.to_unix())
    end

    test "can override the rpc opts" do
      assert {:ok, 1001} =
               Utils.date_to_block_number(
                 1000,
                 nil,
                 rpc_client: Ethers.TestRPCModule,
                 rpc_opts: [timestamp: 111, block: "0x3E9"]
               )

      assert {:ok, 1_693_699_010} =
               Utils.date_to_block_number(
                 ~D[2023-09-03],
                 nil,
                 rpc_client: Ethers.TestRPCModule,
                 rpc_opts: [timestamp: 123, block: "0x11e8fba"]
               )
    end

    test "returns error for non existing blocks" do
      assert {:error, :no_block_found} = Utils.date_to_block_number(~D[2001-01-13])
    end
  end

  describe "maybe_add_gas_limit" do
    test "adds gas limit to the transaction params" do
      assert {:ok, %{gas: gas}} =
               Ethers.Utils.maybe_add_gas_limit(%{
                 from: "0x90F8bf6A479f320ead074411a4B0e7944Ea8c9C1",
                 to: "0xFFcf8FDEE72ac11b5c542428B35EEF5769C409f0",
                 value: 100_000_000_000_000_000
               })

      assert is_binary(gas)
      assert Ethers.Utils.hex_to_integer!(gas) > 0
    end

    test "does not add anything if the params already includes gas" do
      assert {:ok, %{gas: 100}} = Ethers.Utils.maybe_add_gas_limit(%{gas: 100})
    end
  end

  describe "hex_to_integer!" do
    test "raises when the hex input is invalid" do
      assert_raise ArgumentError,
                   "Invalid integer HEX input \"0xrubbish\" reason :invalid_hex",
                   fn -> Ethers.Utils.hex_to_integer!("0xrubbish") end
    end
  end

  describe "hex_decode!" do
    test "raises when the hex input is invalid" do
      assert_raise ArgumentError,
                   "Invalid HEX input \"0xrubbish\"",
                   fn -> Ethers.Utils.hex_decode!("0xrubbish") end
    end
  end

  describe "public_key_from_pem" do
    test "can extract public key from a pem" do
      assert {:ok, pub_key} =
               Utils.public_key_from_pem(
                 "MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAsjtGIk8SxD+OEiBpP2/TJUAF0upwuKGMk6wH8Rwov88VvzJrVm2NCticTk5FUg+UG5r8JArrV4tJPRHQyvqKwF4NiksuvOjv3HyIf4oaOhZjT8hDne1Bfv+cFqZJ61Gk0MjANh/T5q9vxER/7TdUNHKpoRV+NVlKN5bEU/NQ5FQjVXicfswxh6Y6fl2PIFqT2CfjD+FkBPU1iT9qyJYHA38IRvwNtcitFgCeZwdGPoxiPPh1WHY8VxpUVBv/2JsUtrB/rAIbGqZoxAIWvijJPe9o1TY3VlOzk9ASZ1AeatvOir+iDVJ5OpKmLnzc46QgGPUsjIyo6Sje9dxpGtoGQQIDAQAB"
               )

      assert true == is_binary(pub_key)
    end

    test "can extract public key from a pem with head and tail" do
      assert {:ok, pub_key} =
               Utils.public_key_from_pem(
                 "-----BEGIN PUBLIC KEY-----\nMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAsjtGIk8SxD+OEiBpP2/TJUAF0upwuKGMk6wH8Rwov88VvzJrVm2NCticTk5FUg+UG5r8JArrV4tJPRHQyvqKwF4NiksuvOjv3HyIf4oaOhZjT8hDne1Bfv+cFqZJ61Gk0MjANh/T5q9vxER/7TdUNHKpoRV+NVlKN5bEU/NQ5FQjVXicfswxh6Y6fl2PIFqT2CfjD+FkBPU1iT9qyJYHA38IRvwNtcitFgCeZwdGPoxiPPh1WHY8VxpUVBv/2JsUtrB/rAIbGqZoxAIWvijJPe9o1TY3VlOzk9ASZ1AeatvOir+iDVJ5OpKmLnzc46QgGPUsjIyo6Sje9dxpGtoGQQIDAQAB\n-----END PUBLIC KEY-----"
               )

      assert true == is_binary(pub_key)
    end

    test "can not extract public key from an invalid pem" do
      assert_raise ErlangError,
                   fn -> Utils.public_key_from_pem("invalid pem") end
    end
  end
end
