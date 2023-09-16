defmodule Ethers.Types do
  @moduledoc "EVM types and compound type definitions"

  require Logger

  @typedoc """
  Ethereum address in its hex format with 0x or in its binary format

  ## Examples
  - `"0xdAC17F958D2ee523a2206206994597C13D831ec7"`
  - `<<218, 193, 127, 149, 141, 46, 229, 35, 162, 32, 98, 6, 153, 69, 151, 193, 61, 131, 30, 199>>`
  """
  @type t_address :: <<_::336>> | <<_::160>>

  @typedoc """
  keccak hash in its hex format with 0x

  ## Examples
  - `"0xd4288c8e733eb71a39fe2e8dd4912ce54d8d26d9874f30309b26b4b071260422"`
  """
  @type t_hash :: <<_::528>>

  @type t_bitsizes :: unquote(8..256//8 |> Enum.reduce(&{:|, [], [&1, &2]}))
  @type t_bytesizes :: unquote(1..32 |> Enum.reduce(&{:|, [], [&1, &2]}))
  @type t_evm_types ::
          {:uint, t_bitsizes()}
          | {:int, t_bitsizes()}
          | {:bytes, t_bytesizes()}
          | :bytes
          | :string
          | :address
          | {:array, t_evm_types()}
          | {:array, t_evm_types(), non_neg_integer()}
          | {:tuple, [t_evm_types()]}

  @dynamically_sized_types [:string, :bytes]

  defguardp valid_bitsize(bitsize) when bitsize >= 8 and bitsize <= 256 and rem(bitsize, 8) == 0

  @doc """
  Converts EVM data types to typespecs for documentation
  """
  def to_elixir_type(:address) do
    quote do: Ethers.Types.t_address()
  end

  def to_elixir_type({:array, sub_type, _element_count}) do
    to_elixir_type({:array, sub_type})
  end

  def to_elixir_type({:array, sub_type}) do
    sub_type = to_elixir_type(sub_type)

    quote do
      [unquote(sub_type)]
    end
  end

  def to_elixir_type({:bytes, size}) do
    quote do: <<_::unquote(size * 8)>>
  end

  def to_elixir_type(:bytes) do
    quote do: binary()
  end

  def to_elixir_type(:bool) do
    quote do: boolean()
  end

  def to_elixir_type(:function) do
    raise "Function type not supported!"
  end

  def to_elixir_type({:ufixed, _element_count, _precision}) do
    quote do: float()
  end

  def to_elixir_type({:fixed, _element_count, _precision}) do
    quote do: float()
  end

  def to_elixir_type({:int, _}) do
    quote do: integer
  end

  def to_elixir_type(:string) do
    quote do: String.t()
  end

  def to_elixir_type({:tuple, sub_types}) do
    sub_types = Enum.map(sub_types, &to_elixir_type/1)

    quote do: {unquote_splicing(sub_types)}
  end

  def to_elixir_type({:uint, _}) do
    quote do: non_neg_integer
  end

  def to_elixir_type(unknown) do
    Logger.warning("Unknown type #{inspect(unknown)}")
    quote do: term
  end

  @doc """
  Returns the maximum possible value in the given type if supported.

  ## Examples

      iex> Ethers.Types.max({:uint, 8})
      255

      iex> Ethers.Types.max({:int, 8})
      127

      iex> Ethers.Types.max({:uint, 16})
      65535

      iex> Ethers.Types.max({:int, 16})
      32767
  """
  def max(type)

  def max({:uint, bitsize}) when valid_bitsize(bitsize) do
    (:math.pow(2, bitsize) - 1)
    |> trunc()
  end

  def max({:int, bitsize}) when valid_bitsize(bitsize) do
    (:math.pow(2, bitsize - 1) - 1)
    |> trunc()
  end

  @doc """
  Returns the minimum possible value in the given type if supported.

  ## Examples

      iex> Ethers.Types.min({:uint, 8})
      0

      iex> Ethers.Types.min({:int, 8})
      -128

      iex> Ethers.Types.min({:uint, 16})
      0

      iex> Ethers.Types.min({:int, 16})
      -32768

      iex> Ethers.Types.min({:int, 24})
      -8388608
  """
  def min(type)

  def min({:uint, bitsize}) when valid_bitsize(bitsize), do: 0

  def min({:int, bitsize}) when valid_bitsize(bitsize) do
    (-1 * :math.pow(2, bitsize - 1))
    |> trunc()
  end

  @doc """
  Returns the default value in the given type if supported.

  ## Examples

      iex> Ethers.Types.default(:address)
      "0x0000000000000000000000000000000000000000"

      iex> Ethers.Types.default({:int, 32})
      0

      iex> Ethers.Types.default({:uint, 8})
      0

      iex> Ethers.Types.default({:int, 128})
      0

      iex> Ethers.Types.default(:string)
      ""

      iex> Ethers.Types.default(:bytes)
      ""

      iex> Ethers.Types.default({:bytes, 8})
      <<0, 0, 0, 0, 0, 0, 0, 0>>
  """
  def default({type, _}) when type in [:int, :uint], do: 0

  def default(:address), do: "0x0000000000000000000000000000000000000000"

  def default(type) when type in [:string, :bytes], do: ""

  def default({:bytes, size}), do: <<0::size*8>>

  @doc """
  Checks if a given data matches a given solidity type

  ## Examples

      iex> Ethers.Types.matches_type?(false, :bool)
      true

      iex> Ethers.Types.matches_type?(200, {:uint, 8})
      true

      iex> Ethers.Types.matches_type?(400, {:uint, 8})
      false
  """
  @spec matches_type?(term(), t_evm_types()) :: boolean()
  def matches_type?(value, type)

  def matches_type?(value, {:uint, _bsize} = type),
    do: is_integer(value) and value >= 0 and value <= max(type)

  def matches_type?(value, {:int, _bsize} = type),
    do: is_integer(value) and min(type) <= value and value <= max(type)

  def matches_type?(value, :address), do: is_binary(value) and byte_size(value) <= 42

  def matches_type?(value, :string), do: is_binary(value) and String.valid?(value)

  def matches_type?(value, :bytes), do: is_binary(value)

  def matches_type?(value, {:bytes, size}), do: is_binary(value) && byte_size(value) == size

  def matches_type?(value, :bool), do: is_boolean(value)

  def matches_type?(values, {:array, sub_type, element_count}) do
    matches_type?(values, {:array, sub_type}) and Enum.count(values) == element_count
  end

  def matches_type?(values, {:array, sub_type}) do
    is_list(values) and Enum.all?(values, &matches_type?(&1, sub_type))
  end

  def matches_type?(values, {:tuple, sub_types}) do
    if is_tuple(values) and tuple_size(values) == Enum.count(sub_types) do
      Enum.zip(sub_types, Tuple.to_list(values))
      |> Enum.all?(fn {type, value} -> matches_type?(value, type) end)
    else
      false
    end
  end

  @doc false
  def dynamically_sized_types, do: @dynamically_sized_types

  @doc """
  Validates and creates typed values to use with functions or events.

  Typed values are useful when there are multiple overloads of same function or event and you need
  to specify one of them to be used.

  Also raises with ArgumentError in case value does not match the given type.

  ## Examples

      iex> Ethers.Types.typed({:uint, 256}, 5)
      {:typed, {:uint, 256}, 5}

      iex> Ethers.Types.typed(:bytes, <<0, 1, 2>>)
      {:typed, :bytes, <<0, 1, 2>>}
  """
  @spec typed(term(), t_evm_types() | nil) :: {:typed, term(), term()} | no_return()
  def typed(type, nil), do: {:typed, type, nil}

  def typed(type, value) do
    if matches_type?(value, type) do
      {:typed, type, value}
    else
      raise ArgumentError, "Value #{inspect(value)} does not match type #{inspect(type)}"
    end
  end
end
