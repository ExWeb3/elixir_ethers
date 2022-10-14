defmodule Ethers.Utils do
  @moduledoc """
  Utilities for interacting with ethereum blockchain
  """

  @doc """
  Encode to hex with 0x prefix.
  """
  @spec hex_encode(binary()) :: String.t()
  def hex_encode(bin), do: "0x" <> Base.encode16(bin, case: :lower)

  @doc """
  Decode from hex with (or without) 0x prefix.
  """
  @spec hex_decode(String.t()) :: {:ok, binary}
  def hex_decode(<<"0x", encoded::binary>>), do: hex_decode(encoded)
  def hex_decode(encoded) when rem(byte_size(encoded), 2) == 1, do: hex_decode("0" <> encoded)
  def hex_decode(encoded), do: Base.decode16(encoded, case: :mixed)
end
