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

  defguard valid_bitsize(bitsize) when bitsize >= 8 and bitsize <= 256 and rem(bitsize, 8) == 0

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
    quote do: <<_::unquote(size * 8)>> | <<_::unquote(size * 8 * 2 + 2 * 8)>>
  end

  def to_elixir_type(:bytes) do
    quote do: binary()
  end

  def to_elixir_type(:bool) do
    quote do: boolean()
  end

  def to_elixir_type(:function) do
    raise "Not implemented"
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
    Logger.warn("Unknown type #{inspect(unknown)}")
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
end
