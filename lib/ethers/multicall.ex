defmodule Ethers.Multicall do
  @moduledoc """
  Multicall token interface

  More info: https://www.multicall3.com
  """

  import Ethers.Utils, only: [hex_decode!: 1]

  alias Ethers.Contracts.Multicall3
  alias Ethers.TxData

  def aggregate3(data) when is_list(data) do
    data
    |> Enum.map(&aggregate3_encode_data/1)
    |> Multicall3.aggregate3()
  end

  @spec aggregate3_encode_data({Ethers.TxData.t()} | {Ethers.TxData.t(), keyword()}) ::
          {any(), boolean(), binary()}
  def aggregate3_encode_data(data)

  def aggregate3_encode_data({%TxData{data: data}, opts}) do
    {Keyword.fetch!(opts, :to), Keyword.get(opts, :allow_failure, true), hex_decode!(data)}
  end

  def aggregate3_encode_data({%TxData{data: data, default_address: address}, opts})
      when not is_nil(address) do
    {address, Keyword.get(opts, :allow_failure, true), hex_decode!(data)}
  end

  def aggregate3_encode_data({%TxData{data: data, default_address: address}})
      when not is_nil(address) do
    {address, true, hex_decode!(data)}
  end

  def aggregate3_encode_data(%TxData{data: data, default_address: address})
      when not is_nil(address) do
    {address, true, hex_decode!(data)}
  end

  def aggregate2(data) when is_list(data) do
    data
    |> Enum.map(&aggregate2_encode_data/1)
    |> Multicall3.aggregate()
  end

  def aggregate2_encode_data(data)

  def aggregate2_encode_data({%TxData{data: data}, opts}) do
    {Keyword.fetch!(opts, :to), hex_decode!(data)}
  end

  def aggregate2_encode_data({%TxData{data: data, default_address: address}})
      when not is_nil(address) do
    {address, hex_decode!(data)}
  end

  def aggregate2_encode_data(%TxData{data: data, default_address: address})
      when not is_nil(address) do
    {address, hex_decode!(data)}
  end

  # def call!(params, overrides \\ []) do
  #  decode(Ethers.call!(params, overrides), Keyword.get(overrides, :calls))
  # end

  def aggregate2_decode([block, resps], calls) when length(resps) == length(calls) do
    [
      block,
      decode_calls(calls)
      |> Enum.zip(resps)
      |> Enum.map(fn {selector, resp} ->
        decode_resp(selector, resp)
      end)
    ]
  end

  def aggregate3_decode(resps, calls) when length(resps) == length(calls) do
    decode_calls(calls)
    |> Enum.zip(resps)
    |> Enum.map(fn {selector, {success, resp}} ->
      {success, decode_resp(selector, resp)}
    end)
  end

  defp decode_resp(selector, resp) do
    case resp do
      # NOTE: ABI.decode/2 will fail on empty result
      "" ->
        ""

      _ ->
        selector
        |> ABI.decode(resp, :output)
        # Unpack one element lists
        |> case do
          [element] -> element
          list -> list
        end
    end
  end

  defp decode_calls(calls), do: Enum.map(calls, &decode_call/1)

  defp decode_call({%TxData{selector: selector}, _, _}), do: selector
  defp decode_call({%TxData{selector: selector}, _}), do: selector
  defp decode_call({%TxData{selector: selector}}), do: selector
  defp decode_call(%TxData{selector: selector}), do: selector
  defp decode_call(function_signature), do: function_signature
end
