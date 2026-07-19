defmodule Ethers.UtilsTest do
  use ExUnit.Case
  alias Ethers.Utils
  doctest Ethers.Utils

  @rsk_mainnet_addresses [
    "0x27b1FdB04752BBc536007A920D24ACB045561c26",
    "0x3599689E6292B81B2D85451025146515070129Bb",
    "0x42712D45473476B98452f434E72461577d686318",
    "0x52908400098527886E0F7030069857D2E4169ee7",
    "0x5aaEB6053f3e94c9b9a09f33669435E7ef1bEAeD",
    "0x6549F4939460DE12611948B3F82B88C3C8975323",
    "0x66F9664f97f2B50F62d13EA064982F936de76657",
    "0x8617E340b3D01Fa5f11f306f4090fd50E238070D",
    "0x88021160c5C792225E4E5452585947470010289d",
    "0xD1220A0Cf47c7B9BE7a2e6ba89F429762E7B9adB",
    "0xDBF03B407c01E7CD3cBea99509D93F8Dddc8C6FB",
    "0xDe709F2102306220921060314715629080e2FB77",
    "0xFb6916095cA1Df60bb79ce92cE3EA74c37c5d359"
  ]

  @rsk_testnet_addresses [
    "0x27B1FdB04752BbC536007a920D24acB045561C26",
    "0x3599689e6292b81b2D85451025146515070129Bb",
    "0x42712D45473476B98452F434E72461577D686318",
    "0x52908400098527886E0F7030069857D2e4169EE7",
    "0x5aAeb6053F3e94c9b9A09F33669435E7EF1BEaEd",
    "0x6549f4939460dE12611948b3f82b88C3c8975323",
    "0x66f9664F97F2b50f62d13eA064982F936DE76657",
    "0x8617e340b3D01fa5F11f306F4090Fd50e238070d",
    "0x88021160c5C792225E4E5452585947470010289d",
    "0xd1220a0CF47c7B9Be7A2E6Ba89f429762E7b9adB",
    "0xdbF03B407C01E7cd3cbEa99509D93f8dDDc8C6fB",
    "0xDE709F2102306220921060314715629080e2Fb77",
    "0xFb6916095CA1dF60bb79CE92ce3Ea74C37c5D359"
  ]

  describe "get_block_timestamp" do
    test "returns the block timestamp" do
      assert {:ok, n} = Ethers.current_block_number()
      assert {:ok, t} = Utils.get_block_timestamp(n)
      assert is_integer(t)
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
      {:ok, t} = Utils.get_block_timestamp(n)

      assert {:ok, ^n} = Utils.date_to_block_number(t)
      assert {:ok, ^n} = Utils.date_to_block_number(t, n)
      assert {:ok, ^n} = Utils.date_to_block_number(t |> DateTime.from_unix!())
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

  describe "to_checksum_address/1" do
    test "converts address to checksum form" do
      assert Ethers.Utils.to_checksum_address("0x90f8bf6a479f320ead074411a4b0e7944ea8c9c1") ==
               "0x90F8bf6A479f320ead074411a4B0e7944Ea8c9C1"

      assert Ethers.Utils.to_checksum_address("0x90F8BF6A479F320EAD074411A4B0E7944EA8C9C1") ==
               "0x90F8bf6A479f320ead074411a4B0e7944Ea8c9C1"
    end

    test "works with binary addresses" do
      bin_address = Ethers.Utils.hex_decode!("0x90f8bf6a479f320ead074411a4b0e7944ea8c9c1")

      assert Ethers.Utils.to_checksum_address(bin_address) ==
               "0x90F8bf6A479f320ead074411a4B0e7944Ea8c9C1"
    end

    test "does erc-1191 checksum" do
      %{30 => @rsk_mainnet_addresses, 31 => @rsk_testnet_addresses}
      |> Enum.each(fn {chain_id, addresses} ->
        Enum.each(addresses, fn address ->
          assert Ethers.Utils.to_checksum_address(address, chain_id) == address
        end)
      end)
    end
  end

  describe "public_key_to_address/2" do
    @public_key "0x04e68acfc0253a10620dff706b0a1b1f1f5833ea3beb3bde2250d5f271f3563606672ebc45e0b7ea2e816ecb70ca03137b1c9476eec63d4632e990020b7b6fba39"
    test "converts public_key to address" do
      assert Ethers.Utils.public_key_to_address(@public_key) ==
               "0x90F8bf6A479f320ead074411a4B0e7944Ea8c9C1"

      assert Ethers.Utils.public_key_to_address(@public_key, false) ==
               "0x90f8bf6a479f320ead074411a4b0e7944ea8c9c1"
    end

    test "works with binary public_key" do
      bin_public_key = Ethers.Utils.hex_decode!(@public_key)

      assert Ethers.Utils.public_key_to_address(bin_public_key) ==
               "0x90F8bf6A479f320ead074411a4B0e7944Ea8c9C1"
    end
  end

  describe "human_arg/2" do
    test "handles 20-byte binary address" do
      # Regression test: ensure binary addresses are properly converted
      binary_address =
        <<48, 120, 170, 17, 101, 240, 156, 228, 62, 76, 75, 122, 119, 72, 248, 105, 128, 216, 172,
          54>>

      result = Ethers.Utils.human_arg(binary_address, :address)

      assert result == "0x3078aA1165F09ce43E4C4B7a7748f86980d8AC36"
      assert String.starts_with?(result, "0x")
      assert String.length(result) == 42
    end

    test "handles random 20-byte binary address" do
      # Regression test: ensure any 20-byte binary is properly converted
      binary_address =
        <<123, 45, 67, 89, 12, 34, 56, 78, 90, 11, 22, 33, 44, 55, 66, 77, 88, 99, 111, 222>>

      result = Ethers.Utils.human_arg(binary_address, :address)

      assert result == "0x7B2d43590c22384e5A0B16212c37424D58636FDE"
      assert String.starts_with?(result, "0x")
      assert String.length(result) == 42
    end

    test "handles hex string address" do
      # Ensure hex string addresses are checksummed
      hex_address = "0x90f8bf6a479f320ead074411a4b0e7944ea8c9c1"

      result = Ethers.Utils.human_arg(hex_address, :address)

      assert result == "0x90F8bf6A479f320ead074411a4B0e7944Ea8c9C1"
    end

    test "raises on invalid address" do
      assert_raise ArgumentError, ~r/Invalid address/, fn ->
        Ethers.Utils.human_arg("invalid_address", :address)
      end
    end
  end
end
