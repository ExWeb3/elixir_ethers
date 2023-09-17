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
    test "works with every type" do
      [
        {{:uint, 256}, 200},
        {{:int, 256}, -100},
        {{:int, 256}, 100},
        {{:bytes, 2}, <<1, 2>>},
        {:bytes, <<1, 2, 3>>},
        {:bool, true},
        {:bool, false},
        {:string, "hello"},
        {{:array, :bool}, [true, false]},
        {{:array, :bool, 2}, [true, false]},
        {{:tuple, [:bool, :bool]}, {true, false}}
      ]
      |> Enum.each(fn {type, value} ->
        assert {:typed, type, value} == Ethers.Types.typed(type, value)
      end)
    end

    test "works with nil values" do
      assert {:typed, _, nil} = Ethers.Types.typed(:string, nil)
      assert {:typed, _, nil} = Ethers.Types.typed({:uint, 256}, nil)
    end

    test "raises on type mismatch" do
      [
        {{:uint, 16}, 100_000},
        {{:uint, 16}, -1},
        {{:int, 8}, -300},
        {{:int, 8}, 256},
        {{:bytes, 2}, <<1, 2, 3>>},
        {:bytes, false},
        {:bool, 1},
        {:bool, 0},
        {:string, <<0xFFFF::16>>},
        {{:array, :bool}, [true, 1]},
        {{:array, :bool, 2}, [true, false, false]},
        {{:tuple, [:bool, :bool]}, {true, 1}},
        {{:tuple, [:bool, :bool]}, {true, false, false}}
      ]
      |> Enum.each(fn {type, value} ->
        assert_raise ArgumentError,
                     "Value #{inspect(value)} does not match type #{inspect(type)}",
                     fn ->
                       Ethers.Types.typed(type, value)
                     end
      end)
    end
  end
end
