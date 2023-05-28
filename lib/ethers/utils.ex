defmodule Ethers.Utils do
  @moduledoc """
  Utilities for interacting with ethereum blockchain
  """

  alias Ethers.RPC

  @wei_multiplier trunc(:math.pow(10, 18))

  @doc """
  Encode to hex with 0x prefix.

  ## Examples

      iex> Ethers.Utils.hex_encode("ethers_ex")
      "0x6574686572735f6578"
  """
  @spec hex_encode(binary()) :: String.t()
  def hex_encode(bin, include_prefix \\ true),
    do: if(include_prefix, do: "0x", else: "") <> Base.encode16(bin, case: :lower)

  @doc """
  Decode from hex with (or without) 0x prefix.

  ## Examples

      iex> Ethers.Utils.hex_decode("0x6574686572735f6578")
      {:ok, "ethers_ex"}

      iex> Ethers.Utils.hex_decode("6574686572735f6578")
      {:ok, "ethers_ex"}
  """
  @spec hex_decode(String.t()) :: {:ok, binary} | :error
  def hex_decode(<<"0x", encoded::binary>>), do: hex_decode(encoded)
  def hex_decode(encoded) when rem(byte_size(encoded), 2) == 1, do: hex_decode("0" <> encoded)
  def hex_decode(encoded), do: Base.decode16(encoded, case: :mixed)

  @doc """
  Same as `hex_decode/1` but raises on error 

  ## Examples

      iex> Ethers.Utils.hex_decode!("0x6574686572735f6578")
      "ethers_ex"

      iex> Ethers.Utils.hex_decode!("6574686572735f6578")
      "ethers_ex"
  """
  @spec hex_decode!(String.t()) :: binary() | no_return()
  def hex_decode!(encoded) do
    case hex_decode(encoded) do
      {:ok, decoded} -> decoded
      :error -> raise ArgumentError, "Invalid HEX input #{inspect(encoded)}"
    end
  end

  @doc """
  Converts a hexadecimal integer to integer form

  ## Examples

      iex> Ethers.Utils.hex_to_integer("0x11111")
      {:ok, 69905}
  """
  @spec hex_to_integer(String.t()) :: {:ok, integer()} | {:error, :invalid_hex}
  def hex_to_integer("0x"), do: {:error, :invalid_hex}
  def hex_to_integer(<<"0x", encoded::binary>>), do: hex_to_integer(encoded)

  def hex_to_integer(encoded) do
    case Integer.parse(encoded, 16) do
      {integer, ""} ->
        {:ok, integer}

      _ ->
        {:error, :invalid_hex}
    end
  end

  @doc """
  Same as `hex_to_integer/1` but raises on error

  ## Examples

      iex> Ethers.Utils.hex_to_integer!("0x11111")
      69905
  """
  @spec hex_to_integer!(String.t()) :: integer() | no_return()
  def hex_to_integer!(encoded) do
    case hex_to_integer(encoded) do
      {:ok, integer} ->
        integer

      {:error, reason} ->
        raise ArgumentError,
              "Invalid integer HEX input #{inspect(encoded)} reason #{inspect(reason)}"
    end
  end

  @doc """
  Converts integer to its hexadecimal form

  ## Examples

      iex> Ethers.Utils.integer_to_hex(69905)
      "0x11111"
  """
  @spec integer_to_hex(integer()) :: String.t()
  def integer_to_hex(integer) when is_integer(integer) do
    "0x" <> Integer.to_string(integer, 16)
  end

  @doc """
  Converts ETH to WEI

  ## Examples

      iex> Ethers.Utils.to_wei(1)
      1000000000000000000

      iex> Ethers.Utils.to_wei(3.14)
      3140000000000000000
  """
  @spec to_wei(number()) :: non_neg_integer()
  def to_wei(number) when number > 0 do
    trunc(number * @wei_multiplier)
  end

  @doc """
  Convert WEI to ETH

  ## Examples

      iex> Ethers.Utils.from_wei(1000000000000000000)
      1.0

      iex> Ethers.Utils.from_wei(3140000000000000000)
      3.14
  """
  @spec from_wei(non_neg_integer()) :: float()
  def from_wei(number) when is_integer(number) and number > 0 do
    number / @wei_multiplier
  end

  @doc """
  Adds gas limit estimation to the parameters if not already exists

  If option `mult` is given, a gas limit multiplied by `mult` divided by 1000 will be used.
  Default for `mult` is 100. (1%)
  """
  def maybe_add_gas_limit(params, opts \\ [])

  def maybe_add_gas_limit(%{gas: _} = params, _opts) do
    {:ok, params}
  end

  def maybe_add_gas_limit(params, opts) do
    with {:ok, gas} <- RPC.estimate_gas(params, opts) do
      mult = (opts[:mult] || 100) + 1000
      gas = div(mult * gas, 1000)
      {:ok, Map.put(params, :gas, gas)}
    end
  end

  @doc """
  Converts human readable argument to the form required for ABI encoding.

  For example the addresses in Ethereum are represented by hex strings in human readable format
  but are in 160-bit binaries in ABI form.

  ## Examples
      iex> Ethers.Utils.prepare_arg("0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2", :address)
      <<192, 42, 170, 57, 178, 35, 254, 141, 10, 14, 92, 79, 39, 234, 217, 8, 60, 117, 108, 194>> 
  """
  @spec prepare_arg(term(), ABI.FunctionSelector.type()) :: term()
  def prepare_arg("0x" <> _ = argument, :address), do: hex_decode!(argument)
  def prepare_arg(arguments, {:array, type}), do: Enum.map(arguments, &prepare_arg(&1, type))
  def prepare_arg(arguments, {:array, type, _}), do: Enum.map(arguments, &prepare_arg(&1, type))

  def prepare_arg(arguments, {:tuple, types}) do
    arguments
    |> Tuple.to_list()
    |> Enum.zip(types)
    |> Enum.map(fn {arg, type} -> prepare_arg(arg, type) end)
    |> List.to_tuple()
  end

  def prepare_arg(argument, _type), do: argument

  @doc """
  Reverse of `prepare_arg/2`

  ## Examples
      iex> Ethers.Utils.human_arg(<<192, 42, 170, 57, 178, 35, 254, 141, 10, 14, 92, 79, 39, 
      ...> 234, 217, 8, 60, 117, 108, 194>>, :address)
      "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2" 
  """
  @spec human_arg(term(), ABI.FunctionSelector.type()) :: term()
  def human_arg("0x" <> _ = argument, :address), do: argument
  def human_arg(argument, :address), do: hex_encode(argument)

  def human_arg(arguments, {:array, type}), do: Enum.map(arguments, &human_arg(&1, type))
  def human_arg(arguments, {:array, type, _}), do: Enum.map(arguments, &human_arg(&1, type))

  def human_arg(arguments, {:tuple, types}) do
    arguments
    |> Tuple.to_list()
    |> Enum.zip(types)
    |> Enum.map(fn {arg, type} -> human_arg(arg, type) end)
    |> List.to_tuple()
  end

  def human_arg(argument, _type), do: argument
end
