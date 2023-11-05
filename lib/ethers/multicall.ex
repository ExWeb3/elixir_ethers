defmodule Ethers.Multicall do
  @moduledoc """
  High-level module providing convenient utilities and an easy-to-use API for interecting with
  `Multicall3` (more info https://www.multicall3.com).

  This module aggregates multiple **read-only** Ethereum contract calls into a single eth_call
  which can be passed to `Ethers.call/2`. The response can then be passed to
  `Ethers.Multicall.decode/2` for decoding responses returned by the `Multicall3` contract.

  ## Examples
  ```elixir
  calls = [
    ContractA.foo(),
    {ContractB.foo(), to: "0x..."},
  ]

  calls
  |> Multicall.aggregate3() # Or can use `Multicall.aggregate2`
  |> Ethers.call!()
  |> Multicall.decode(calls)
  ```
  """

  import Ethers.Utils, only: [hex_decode!: 1]

  alias Ethers.Contracts.Multicall3
  alias Ethers.TxData

  @typep aggregate3_options :: [to: Ethers.Types.t_address(), allow_failure: boolean()]
  @typep aggregate2_options :: [to: Ethers.Types.t_address()]

  @doc """
  Aggregate calls, ensuring each returns success if required. Returns an
  `Ethers.TxData` which can be passed to `Ethers.call/2`.
  More info at: https://github.com/mds1/multicall#batch-contract-reads

  ## Parameters
  - data: A list of `TxData` structs or `{%TxData{...}, options}` tuples. The options can include:
    - allow_failure: If false the execution will revert. Defaults to true.
    - to: Overrides the `default_address` (if any) for the respective function call.

  ## Examples
  ```elixir
  [
    ContractA.foo(), # <-- Assumes `default_address` in ContractA is defined.
    { ContractA.foo() }, # <-- Equivalent to the above.
    { ContractB.bar(), to: "0x..." }, # <-- ContractB.bar() will call `to`.
    { ContractC.baz(), allow_failure: false, to: "0x..." }
    # ^^^ -> ContractC.baz() will call `to` and will revert on failure.
    { ContractD.foo(), allow_failure: false } # <-- ContractD.foo() will revert on failure.
  ] |> aggregate3()
  #Ethers.TxData<
  function aggregate3(
    (address,bool,bytes)[] calls [...]
  ) payable returns (
    (bool,bytes)[] returnData
  )
  default_address: "0xcA11bde05977b3631167028862bE2a173976CA11"
  >
  ```
  """
  @spec aggregate3([
          Ethers.TxData.t()
          | {Ethers.TxData.t(), aggregate3_options}
        ]) :: Ethers.TxData.t()
  def aggregate3(data) when is_list(data) do
    data
    |> Enum.map(&aggregate3_encode_data/1)
    |> Multicall3.aggregate3()
  end

  @doc """
  Encodes a function call with optional options into a solidity compatible (address,bool,bytes).

  ## Parameters
  - data: A function call with optional options
    - allow_failure: If false the execution will revert. Defaults to true.
    - to: Overrides the `default_address` (if any) for the respective function call.

  ## Examples
  ```elixir
  { ContractA.foo(), allow_failure: false } |> aggregate3_encode_data()
  {"0x...", false, <<...>>}

  ContractB.bar() |> aggregate3_encode_data()
  {"0x...", true, <<...>>}
  ```
  """
  @spec aggregate3_encode_data(
          Ethers.TxData.t()
          | {Ethers.TxData.t()}
          | {Ethers.TxData.t(), aggregate3_options}
        ) :: {Ethers.Types.t_address(), boolean(), binary()}
  def aggregate3_encode_data(data)

  def aggregate3_encode_data({%TxData{data: data, default_address: address}, opts})
      when not is_nil(address) do
    {address, Keyword.get(opts, :allow_failure, true), hex_decode!(data)}
  end

  def aggregate3_encode_data({%TxData{data: data}, opts}) do
    {Keyword.fetch!(opts, :to), Keyword.get(opts, :allow_failure, true), hex_decode!(data)}
  end

  def aggregate3_encode_data({%TxData{data: data, default_address: address}})
      when not is_nil(address) do
    {address, true, hex_decode!(data)}
  end

  def aggregate3_encode_data(%TxData{data: data, default_address: address})
      when not is_nil(address) do
    {address, true, hex_decode!(data)}
  end

  @doc """
  Aggregate calls, returning the executed block number and will revert if any
  call fails. Returns an `Ethers.TxData` which can be passed to `Ethers.call/2`.
  More info at: https://github.com/mds1/multicall#batch-contract-reads

  ## Parameters
  - data: A list of function calls with optional options
    - to: Overrides the `default_address` (if any) for the respective function call.

  ## Examples
  ```elixir
  [
    ContractA.foo(), # <-- Assumes `default_address` in ContractA is defined.
    { ContractA.foo() }, # <-- Equivalent to the above.
    { ContractB.bar(), to: "0x..." }, # <-- ContractB.bar() will call `to`.
  ] |> aggregate2()
  #Ethers.TxData<
  function aggregate(
    (address,bytes)[] calls [...]
  ) payable returns (
    uint256 blockNumber,
    bytes[] returnData
  )
  default_address: "0xcA11bde05977b3631167028862bE2a173976CA11"
  >
  ```
  """
  @spec aggregate2([
          Ethers.TxData.t()
          | {Ethers.TxData.t()}
          | {Ethers.TxData.t(), aggregate2_options}
        ]) :: Ethers.TxData.t()
  def aggregate2(data) when is_list(data) do
    data
    |> Enum.map(&aggregate2_encode_data/1)
    |> Multicall3.aggregate()
  end

  @doc """
  Encodes a function call with optional options into a solidity compatible (address,bytes).

  ## Parameters
  - data: A function call with optional options
    - to: Overrides the `default_address` (if any) for the respective function call.

  ## Examples
  ```elixir
  { ContractA.foo(), to: "0x1337..." } |> aggregate2_encode_data()
  {"0x1337...", false, <<...>>}

  ContractB.bar() |> aggregate2_encode_data()
  {"0x...", <<...>>}
  ```
  """
  @spec aggregate2_encode_data(
          Ethers.TxData.t()
          | {Ethers.TxData.t()}
          | {Ethers.TxData.t(), aggregate2_options}
        ) :: {Ethers.Types.t_address(), binary()}
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
  Decodes a `Multicall3` response from `Ethers.call/2`.`

  ## Parameters
  - resps: The response from `Ethers.call/2`.
  - calls: A list of the function calls or signatures passed to `aggregate3/2` or `aggregate2/2`.

  ## Examples
  ```elixir
  calls = [ ContractA.foo(), { ContractB.foo(), to: "0x..." } ]
  calls |> Ethers.Multicall.aggregate3() |> Ethers.call!() |> Ethers.Multicall.decode(calls)
  [ true: "bar", true: "baz" ]

  calls = [ ContractA.foo(), { ContractB.foo(), to: "0x..." } ]
  calls |> Ethers.Multicall.aggregate2() |> Ethers.call!() |> Ethers.Multicall.decode(calls)
  [ 1337, [ "bar", "baz" ]]
  ```
  """
  @spec decode(
          [%{(true | false) => any()}] | [integer() | [...]],
          [Ethers.TxData.t() | binary()]
        ) :: [%{(true | false) => any()}] | [integer() | [...]]
  def decode(resps, calls)

  def decode([block, resps], calls) when is_integer(block) do
    aggregate2_decode([block, resps], calls)
  end

  def decode(resps, calls) do
    aggregate3_decode(resps, calls)
  end

  @doc """
  Decodes an `aggregate3/2` response from `Ethers.call/2`.

  ## Parameters
  - resps: The response from `Ethers.call/2`.
  - calls: A list of the function calls or signatures passed to `aggregate3/2`.

  ## Examples
  ```elixir
  calls = [ ContractA.foo(), { ContractB.foo(), to: "0x..." } ]
  calls
  |> Ethers.Multicall.aggregate3()
  |> Ethers.call!()
  |> Ethers.Multicall.aggregate3_decode(calls)
  [ true: "bar", true: "baz" ]
  ```
  """
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

  @doc """
  Decodes an `aggregate2/2` response from `Ethers.call/2`.

  ## Parameters
  - resps: The response from `Ethers.call/2`.
  - calls: A list of the function calls or signatures passed to `aggregate2/2`.

  ## Examples
  ```elixir
  calls = [ ContractA.foo(), { ContractB.foo(), to: "0x..." } ]
  calls
  |> Ethers.Multicall.aggregate2()
  |> Ethers.call!()
  |> Ethers.Multicall.aggregate2_decode(calls)
  [ 1337, [ "bar", "baz" ]]
  ```
  """
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

  defp decode_call({%TxData{selector: selector}, _}), do: selector
  defp decode_call({%TxData{selector: selector}}), do: selector
  defp decode_call(%TxData{selector: selector}), do: selector
  defp decode_call(function_signature), do: function_signature
end
