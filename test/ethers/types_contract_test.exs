defmodule Ethers.Contract.Test.TypesContract do
  @moduledoc false
  use Ethers.Contract, abi_file: "tmp/types_abi.json"
end

defmodule Ethers.TypesContractTest do
  use ExUnit.Case
  doctest Ethers.Contract

  alias Ethers.Contract.Test.TypesContract

  @from "0x90F8bf6A479f320ead074411a4B0e7944Ea8c9C1"
  @sample_address "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2"

  setup_all :deploy_types_contract

  describe "encode/decode" do
    test "uint types", %{address: address} do
      assert {:ok, [100]} = TypesContract.get_uint8(100, to: address)
      assert {:ok, [100]} = TypesContract.get_uint16(100, to: address)
      assert {:ok, [100]} = TypesContract.get_uint32(100, to: address)
      assert {:ok, [100]} = TypesContract.get_uint64(100, to: address)
      assert {:ok, [100]} = TypesContract.get_uint128(100, to: address)
      assert {:ok, [100]} = TypesContract.get_uint256(100, to: address)
    end

    test "int types", %{address: address} do
      assert {:ok, [-101]} = TypesContract.get_int8(-101, to: address)
      assert {:ok, [-101]} = TypesContract.get_int16(-101, to: address)
      assert {:ok, [-101]} = TypesContract.get_int32(-101, to: address)
      assert {:ok, [-101]} = TypesContract.get_int64(-101, to: address)
      assert {:ok, [-101]} = TypesContract.get_int128(-101, to: address)
      assert {:ok, [-101]} = TypesContract.get_int256(-101, to: address)
    end

    test "boolean type", %{address: address} do
      assert {:ok, [false]} = TypesContract.get_bool(false, to: address)
      assert {:ok, [true]} = TypesContract.get_bool(true, to: address)
    end

    test "string type", %{address: address} do
      assert {:ok, ["a string"]} = TypesContract.get_string("a string", to: address)
      assert {:ok, [""]} = TypesContract.get_string("", to: address)
      assert {:ok, [<<0>>]} = TypesContract.get_string(<<0>>, to: address)
    end

    test "address type", %{address: address} do
      assert {:ok, [@sample_address]} = TypesContract.get_address(@sample_address, to: address)
    end

    test "bytes type", %{address: address} do
      assert {:ok, [<<0, 1, 2, 3>>]} = TypesContract.get_bytes(<<0, 1, 2, 3>>, to: address)
      assert {:ok, [<<1234::1024>>]} = TypesContract.get_bytes(<<1234::1024>>, to: address)
    end

    test "fixed bytes type", %{address: address} do
      assert {:ok, [<<1>>]} = TypesContract.get_bytes1(<<1>>, to: address)
      assert {:ok, [<<1::20*8>>]} = TypesContract.get_bytes20(<<1::20*8>>, to: address)
      assert {:ok, [<<1::32*8>>]} = TypesContract.get_bytes32(<<1::32*8>>, to: address)
    end

    test "struct type", %{address: address} do
      assert {:ok, [{100, -101, @sample_address}]} =
               TypesContract.get_struct({100, -101, @sample_address}, to: address)
    end

    test "array type", %{address: address} do
      assert {:ok, [[1, 2, -3]]} = TypesContract.get_int256_array([1, 2, -3], to: address)
      assert {:ok, [[100, 2, 4]]} = TypesContract.get_fixed_uint_array([100, 2, 4], to: address)

      assert {:ok, [[{5, -10, @sample_address}, {1, 900, @sample_address}]]} =
               TypesContract.get_struct_array(
                 [{5, -10, @sample_address}, {1, 900, @sample_address}],
                 to: address
               )
    end
  end

  defp deploy_types_contract(_ctx) do
    init_params = TypesContract.constructor()
    assert {:ok, tx_hash} = Ethers.deploy(TypesContract, init_params, %{from: @from})
    assert {:ok, address} = Ethers.deployed_address(tx_hash)

    [address: address]
  end
end
