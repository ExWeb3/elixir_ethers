defmodule Ethers.TypesTest do
  use ExUnit.Case
  alias Ethers.Types
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
        Types.to_elixir_type(:function)
      end
    end
  end

  describe "valid_bitsize guard" do
    test "accepts all valid bitsizes" do
      Enum.reduce(8..256//8, 0, fn bitsize, last_uint_max ->
        uint_max = Types.max({:uint, bitsize})
        int_max = Types.max({:int, bitsize})
        assert uint_max > int_max
        assert uint_max > last_uint_max
        uint_max
      end)
    end

    test "raises on invalid bitsize" do
      assert_raise FunctionClauseError, fn -> Types.max({:uint, 9}) end
    end
  end

  describe "matches_type?/2" do
    test "works with uint" do
      assert Types.matches_type?(0, {:uint, 8})
      assert Types.matches_type?(255, {:uint, 8})
      refute Types.matches_type?(256, {:uint, 8})
      refute Types.matches_type?(-1, {:uint, 8})

      assert Types.matches_type?(Types.max({:uint, 256}), {:uint, 256})
      refute Types.matches_type?(Types.max({:uint, 256}) + 1, {:uint, 256})
    end

    test "works with int" do
      assert Types.matches_type?(0, {:int, 8})
      assert Types.matches_type?(127, {:int, 8})
      assert Types.matches_type?(-1, {:int, 8})
      assert Types.matches_type?(-128, {:int, 8})

      refute Types.matches_type?(128, {:int, 8})
      refute Types.matches_type?(-129, {:int, 8})

      assert Types.matches_type?(Types.max({:int, 256}), {:int, 256})
      refute Types.matches_type?(Types.max({:int, 256}) + 1, {:int, 256})

      assert Types.matches_type?(Types.min({:int, 256}), {:int, 256})
      refute Types.matches_type?(Types.min({:int, 256}) - 1, {:int, 256})
    end

    test "works with address" do
      assert Types.matches_type?("0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2", :address)
      refute Types.matches_type?("0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc20", :address)
      refute Types.matches_type?("c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2", :address)
      refute Types.matches_type?("0x0", :address)

      assert Types.matches_type?(:crypto.strong_rand_bytes(20), :address)
    end

    test "works with strings" do
      assert Types.matches_type?("hi", :string)
      assert Types.matches_type?("hi this is a longer string", :string)

      refute Types.matches_type?(<<0xFFFF::16>>, :string)
      refute Types.matches_type?(100, :string)
    end

    test "works with dynamic sized byte arrays" do
      assert Types.matches_type?(<<>>, :bytes)
      assert Types.matches_type?(<<1, 2, 3>>, :bytes)
      assert Types.matches_type?(:crypto.strong_rand_bytes(100), :bytes)

      refute Types.matches_type?(100, :bytes)
    end

    test "works with static sized byte arrays" do
      assert Types.matches_type?(<<1>>, {:bytes, 1})
      assert Types.matches_type?(<<1, 2, 3>>, {:bytes, 3})
      assert Types.matches_type?(:crypto.strong_rand_bytes(32), {:bytes, 32})

      refute Types.matches_type?(<<>>, {:bytes, 1})
      refute Types.matches_type?(<<1, 2>>, {:bytes, 1})
      refute Types.matches_type?(<<1, 2, 3>>, {:bytes, 16})
      refute Types.matches_type?(<<1, 2, 3>>, {:bytes, 32})

      assert_raise(ArgumentError, "Invalid size: 0 (must be 1 <= size <= 32)", fn ->
        Types.matches_type?(<<>>, {:bytes, 0})
      end)

      assert_raise(ArgumentError, "Invalid size: 33 (must be 1 <= size <= 32)", fn ->
        Types.matches_type?(<<>>, {:bytes, 33})
      end)
    end

    test "works with booleans" do
      assert Types.matches_type?(true, :bool)
      assert Types.matches_type?(false, :bool)

      refute Types.matches_type?(nil, :bool)
      refute Types.matches_type?(0, :bool)
      refute Types.matches_type?(1, :bool)
    end

    test "works with dynamic length arrays" do
      assert Types.matches_type?([], {:array, :bool})
      assert Types.matches_type?([true], {:array, :bool})
      assert Types.matches_type?([false, true], {:array, :bool})

      refute Types.matches_type?([0], {:array, :bool})
      refute Types.matches_type?([true, 0], {:array, :bool})
    end

    test "works with static length arrays" do
      assert Types.matches_type?([true], {:array, :bool, 1})
      assert Types.matches_type?([false, true], {:array, :bool, 2})

      refute Types.matches_type?([], {:array, :bool, 1})
      refute Types.matches_type?([false, true], {:array, :bool, 3})
      refute Types.matches_type?([true, 0], {:array, :bool, 2})
    end

    test "works with tuples" do
      assert Types.matches_type?({true}, {:tuple, [:bool]})
      assert Types.matches_type?({true, 100}, {:tuple, [:bool, {:uint, 256}]})

      refute Types.matches_type?({true, -100}, {:tuple, [:bool, {:uint, 256}]})
      refute Types.matches_type?([true, 100], {:tuple, [:bool, {:uint, 256}]})
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
        assert {:typed, type, value} == Types.typed(type, value)
      end)
    end

    test "works with nil values" do
      assert {:typed, _, nil} = Types.typed(:string, nil)
      assert {:typed, _, nil} = Types.typed({:uint, 256}, nil)
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
                       Types.typed(type, value)
                     end
      end)
    end
  end
end
