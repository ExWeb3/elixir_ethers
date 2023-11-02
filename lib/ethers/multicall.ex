defmodule Ethers.Multicall do
  @moduledoc """
  Multicall token interface

  More info: https://www.multicall3.com
  """

  import Ethers.Utils, only: [hex_decode!: 1]

  alias Ethers.Contracts.Multicall3
  alias Ethers.ExecutionError
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

  @doc """
  Makes an eth_call to with the given data and overrides using Ethers.call/2.
  The responses are parsed and decoded using `:calls` provided in the overrides.
  Assumes the call is to Multicall, either from a prepared aggregate2 or aggregate3.

  ## Overrides and Options
    All from `Ethers.call/2`, and:

    - `:calls`: List of function calls or selectors. Used for decoding results.

  ## Examples

  ```elixir
  calls = [ ContractA.foo(), { ContractB.foo(), to: "0x..." } ]
  calls |> Ethers.Multicall.aggregate3() |> Ethers.Multicall.call(calls: calls)
  {:ok, [ true: "bar", true: "baz" ]}
  ```
  """
  @spec call(Ethers.TxData.t(), Keyword.t()) :: {:ok, any()} | {:error, term()}
  def call(params, overrides \\ []) do
    {calls, overrides} = Keyword.pop(overrides, :calls)

    case Ethers.call(params, overrides) do
      {:ok, result} -> {:ok, decode(result, calls)}
      {:error, cause} -> {:error, cause}
    end
  end

  @doc """
  Same as `Ethers.Multicall.call/2` but raises on error.
  """
  @spec call!(Ethers.TxData.t(), Keyword.t()) :: any() | no_return()
  def call!(params, overrides \\ []) do
    case Ethers.Multicall.call(params, overrides) do
      {:ok, result} -> result
      {:error, reason} -> raise ExecutionError, reason
    end
  end

  @spec decode(any(), nil | [binary() | Ethers.TxData.t()]) :: any()
  def decode(resps, calls)

  def decode(resps, nil), do: resps

  def decode([block, resps], calls) when is_integer(block) do
    aggregate2_decode([block, resps], calls)
  end

  def decode(resps, calls) do
    aggregate3_decode(resps, calls)
  end

  @spec aggregate3_decode([%{(true | false) => any()}], [TxData.t()] | [binary()]) :: [
          %{(true | false) => any()}
        ]
  def aggregate3_decode(resps, calls) when length(resps) == length(calls) do
    decode_calls(calls)
    |> Enum.zip(resps)
    |> Enum.map(fn {selector, {success, resp}} ->
      {success, decode_resp(selector, resp)}
    end)
  end

  @spec aggregate2_decode([integer() | [...]], [TxData.t()] | [binary()]) :: [integer() | [...]]
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
