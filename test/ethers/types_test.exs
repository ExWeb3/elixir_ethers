defmodule Ethers.TypesTest do
  use ExUnit.Case
  doctest Ethers.Types

  import ExUnit.CaptureLog

  describe "to_elixir_type" do
    test "emits warning in case of no type match" do
      assert capture_log(fn ->
               assert {:term, [], _} = Ethers.Types.to_elixir_type(:non_existing_type)
             end) =~ "Unknown type :non_existing_type"
    end

    test "does not support function type" do
      assert_raise RuntimeError, "Function type not supported!", fn ->
        Ethers.Types.to_elixir_type(:function)
      end
    end
  end

  describe "valid_bitsize guard" do
    test "accepts all valid bitsizes" do
      Enum.reduce(8..256//8, 0, fn bitsize, last_uint_max ->
        uint_max = Ethers.Types.max({:uint, bitsize})
        int_max = Ethers.Types.max({:int, bitsize})
        assert uint_max > int_max
        assert uint_max > last_uint_max
        uint_max
      end)
    end

    test "raises on invalid bitsize" do
      assert_raise FunctionClauseError, fn -> Ethers.Types.max({:uint, 9}) end
    end
  end

  describe "typed/2" do
    test "raises on type mismatch" do
      assert_raise ArgumentError, "Value -5 does not match type {:uint, 256}", fn ->
        Ethers.Types.typed({:uint, 256}, -5)
      end
    end
  end
end
