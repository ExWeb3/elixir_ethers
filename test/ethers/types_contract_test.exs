defmodule Ethers.Contract.Test.TypesContract do
  @moduledoc false
  use Ethers.Contract, abi_file: "tmp/types_abi.json"
end

defmodule Ethers.TypesContractTest do
  use ExUnit.Case
  doctest Ethers.Contract

  import Ethers.TestHelpers

  alias Ethers.Contract.Test.TypesContract

  @from "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
  @sample_address "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2"

  setup_all :deploy_types_contract

  describe "encode/decode" do
    test "uint types", %{address: address} do
      assert {:ok, 100} = TypesContract.get_uint8(100) |> Ethers.call(to: address)
      assert {:ok, 100} = TypesContract.get_uint16(100) |> Ethers.call(to: address)
      assert {:ok, 100} = TypesContract.get_uint32(100) |> Ethers.call(to: address)
      assert {:ok, 100} = TypesContract.get_uint64(100) |> Ethers.call(to: address)
      assert {:ok, 100} = TypesContract.get_uint128(100) |> Ethers.call(to: address)
      assert {:ok, 100} = TypesContract.get_uint256(100) |> Ethers.call(to: address)
    end

    test "int types", %{address: address} do
      assert {:ok, -101} = TypesContract.get_int8(-101) |> Ethers.call(to: address)
      assert {:ok, -101} = TypesContract.get_int16(-101) |> Ethers.call(to: address)
      assert {:ok, -101} = TypesContract.get_int32(-101) |> Ethers.call(to: address)
      assert {:ok, -101} = TypesContract.get_int64(-101) |> Ethers.call(to: address)
      assert {:ok, -101} = TypesContract.get_int128(-101) |> Ethers.call(to: address)
      assert {:ok, -101} = TypesContract.get_int256(-101) |> Ethers.call(to: address)
    end

    test "boolean type", %{address: address} do
      assert {:ok, false} = TypesContract.get_bool(false) |> Ethers.call(to: address)
      assert {:ok, true} = TypesContract.get_bool(true) |> Ethers.call(to: address)
    end

    test "string type", %{address: address} do
      assert {:ok, "a string"} =
               TypesContract.get_string("a string") |> Ethers.call(to: address)

      assert {:ok, ""} = TypesContract.get_string("") |> Ethers.call(to: address)
      assert {:ok, <<0>>} = TypesContract.get_string(<<0>>) |> Ethers.call(to: address)
    end

    test "address type", %{address: address} do
      assert {:ok, @sample_address} =
               TypesContract.get_address(@sample_address) |> Ethers.call(to: address)
    end

    test "bytes type", %{address: address} do
      assert {:ok, <<0, 1, 2, 3>>} =
               TypesContract.get_bytes(<<0, 1, 2, 3>>) |> Ethers.call(to: address)

      assert {:ok, <<1234::1024>>} =
               TypesContract.get_bytes(<<1234::1024>>) |> Ethers.call(to: address)
    end

    test "fixed bytes type", %{address: address} do
      assert {:ok, <<1>>} = TypesContract.get_bytes1(<<1>>) |> Ethers.call(to: address)

      assert {:ok, <<1::20*8>>} =
               TypesContract.get_bytes20(<<1::20*8>>) |> Ethers.call(to: address)

      assert {:ok, <<1::32*8>>} =
               TypesContract.get_bytes32(<<1::32*8>>) |> Ethers.call(to: address)
    end

    test "struct type", %{address: address} do
      assert {:ok, {100, -101, @sample_address}} =
               TypesContract.get_struct({100, -101, @sample_address}) |> Ethers.call(to: address)
    end

    test "array type", %{address: address} do
      assert {:ok, [1, 2, -3]} =
               TypesContract.get_int256_array([1, 2, -3]) |> Ethers.call(to: address)

      assert {:ok, [100, 2, 4]} =
               TypesContract.get_fixed_uint_array([100, 2, 4]) |> Ethers.call(to: address)

      assert {:ok, [{5, -10, @sample_address}, {1, 900, @sample_address}]} =
               TypesContract.get_struct_array([
                 {5, -10, @sample_address},
                 {1, 900, @sample_address}
               ])
               |> Ethers.call(to: address)
    end
  end

  defp deploy_types_contract(_ctx) do
    address = deploy(TypesContract, encoded_constructor: TypesContract.constructor(), from: @from)

    [address: address]
  end
end
