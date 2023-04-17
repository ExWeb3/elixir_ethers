defmodule Ethers.Utils do
  @moduledoc """
  Utilities for interacting with ethereum blockchain
  """

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
  @spec hex_decode(String.t()) :: {:ok, binary}
  def hex_decode(<<"0x", encoded::binary>>), do: hex_decode(encoded)
  def hex_decode(encoded) when rem(byte_size(encoded), 2) == 1, do: hex_decode("0" <> encoded)
  def hex_decode(encoded), do: Base.decode16(encoded, case: :mixed)

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
  Adds gas limit estimation to the parameters if not already exists
  """
  def maybe_add_gas_limit(params, opts \\ [])

  def maybe_add_gas_limit(%{gas: _} = params, opts) do
    {:ok, params}
  end

  def maybe_add_gas_limit(params, opts) do
    with {:ok, gas} <- Ethers.estimate_gas(params, opts) do
      {:ok, Map.put(params, :gas, gas)}
    end
  end
end
