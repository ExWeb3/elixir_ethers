defmodule Ethers.Multicall do
  @moduledoc """
  This module offers convenient utilities and a user-friendly API for interacting with
  `Multicall3` (for more information, visit https://www.multicall3.com).

  The primary function of this module is to aggregate multiple Ethereum contract calls
  into a single operation. This aggregated call can be subsequently submitted using `Ethers.call/2`
  or `Ethers.send/2` (If you know what you are doing!).

  Upon receiving the response, it can be decoded using `Ethers.Multicall.decode/2` to interpret the
  results returned by the `Multicall3` contract.

  ## How to use
  ```elixir
  calls = [
    ContractA.foo(),
    {ContractB.foo(), to: "0x..."},
  ]

  calls
  |> Ethers.Multicall.aggregate3() # Or `Ethers.Multicall.aggregate2/1`
  |> Ethers.call!()
  |> Ethers.Multicall.decode(calls)
  ```
  """

  import Ethers.Utils, only: [hex_decode!: 1]

  alias Ethers.Contracts.Multicall3
  alias Ethers.TxData

  @typep aggregate3_options :: [to: Ethers.Types.t_address(), allow_failure: boolean()]
  @typep aggregate2_options :: [to: Ethers.Types.t_address()]

  @doc """
  Aggregates calls, ensuring each returns success if required, and returns a `Ethers.TxData` struct,
  which can be passed to `Ethers.call/2`.

  For more details, refer to: https://github.com/mds1/multicall#batch-contract-reads

  ## Parameters
  - `data`: A list of `Ethers.TxData` structs or `{%Ethers.TxData{...}, options}` tuples. The options
  can include:
    - `allow_failure`: If set to `false`, the execution will revert. Defaults to `true`.
    - `to`: Overrides the `default_address` (if any) for the respective function call.

  ## Examples
  ```elixir
  Ethers.Multicall.aggregate3([
    ContractA.foo(), # <-- Assumes `default_address` in ContractA is defined.
    { ContractB.bar(), to: "0x..." }, # <-- ContractB.bar() will call `to`.
    { ContractC.baz(), allow_failure: false, to: "0x..." }
    # ^^^ -> ContractC.baz() will call `to` and will revert on failure.
    { ContractD.foo(), allow_failure: false } # <-- ContractD.foo() will revert on failure.
  ])
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
          TxData.t()
          | {TxData.t(), aggregate3_options}
        ]) :: TxData.t()
  def aggregate3(data) when is_list(data) do
    data
    |> Enum.map(&aggregate3_encode_data/1)
    |> Multicall3.aggregate3()
  end

  @doc """
  Encodes a function call with optional options into a multicall3 compatible (address,bool,bytes)
  tuple.

  ## Parameters
  - data: A `Ethers.TxData` struct or `{%Ethers.TxData{...}, options}`. The options can include:
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
          TxData.t()
          | {TxData.t(), aggregate3_options}
        ) :: {Ethers.Types.t_address(), boolean(), binary()}
  def aggregate3_encode_data(data)

  def aggregate3_encode_data({%TxData{data: data} = tx_data, opts}) do
    {fetch_address!(tx_data, opts), Keyword.get(opts, :allow_failure, true), hex_decode!(data)}
  end

  def aggregate3_encode_data(%TxData{} = tx_data), do: aggregate3_encode_data({tx_data, []})

  @doc """
  Aggregate calls, returning the executed block number and will revert if any
  call fails. Returns a `Ethers.TxData` struct which can be passed to `Ethers.call/2`.

  For more information refer to https://github.com/mds1/multicall#batch-contract-reads

  ## Parameters
  - data: A list of `TxData` structs or `{%TxData{...}, options}` tuples. The options can include:
    - to: Overrides the `default_address` (if any) for the respective function call.

  ## Examples
  ```elixir
  Ethers.Multicall.aggregate2([
    ContractA.foo(), # <-- Assumes `default_address` in ContractA is defined.
    { ContractB.bar(), to: "0x..." }, # <-- ContractB.bar() will call `to`.
  ])
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
          TxData.t()
          | {TxData.t(), aggregate2_options}
        ]) :: TxData.t()
  def aggregate2(data) when is_list(data) do
    data
    |> Enum.map(&aggregate2_encode_data/1)
    |> Multicall3.aggregate()
  end

  @doc """
  Encodes a function call with optional options into a solidity compatible (address,bytes).

  ## Parameters
  - data:  A `TxData` structs or `{%TxData{...}, options}` tuple. The options can include:
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
          TxData.t()
          | {TxData.t(), aggregate2_options}
        ) :: {Ethers.Types.t_address(), binary()}
  def aggregate2_encode_data(data)

  def aggregate2_encode_data({%TxData{data: data} = tx_data, opts}) do
    {fetch_address!(tx_data, opts), hex_decode!(data)}
  end

  def aggregate2_encode_data(%TxData{} = tx_data), do: aggregate2_encode_data({tx_data, []})

  @doc """
  Decodes a `Multicall3` response from `Ethers.call/2`.

  ## Parameters
  - resps: List of results returned by aggregate call (The response from `Ethers.call/2`).
  - calls: List of the function calls or signatures passed to `aggregate3/2` or `aggregate2/2`.
    (used for decoding)

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
          [%{(true | false) => term()}] | [integer() | [...]],
          [TxData.t() | binary()]
        ) :: [%{(true | false) => term()}] | [integer() | [...]]
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
  @spec aggregate3_decode([%{(true | false) => term()}], [TxData.t()] | [binary()]) :: [
          %{(true | false) => term()}
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

  defp decode_resp(_selector, ""), do: nil

  defp decode_resp(selector, resp) do
    selector
    |> ABI.decode(resp, :output)
    # Unpack one element lists
    |> case do
      [element] -> element
      list -> list
    end
  end

  defp decode_calls(calls), do: Enum.map(calls, &decode_call/1)

  defp decode_call({%TxData{selector: selector}, _}), do: selector
  defp decode_call({%TxData{selector: selector}}), do: selector
  defp decode_call(%TxData{selector: selector}), do: selector
  defp decode_call(function_signature), do: function_signature

  defp fetch_address!(%TxData{default_address: nil}, opts), do: Keyword.fetch!(opts, :to)

  defp fetch_address!(%TxData{default_address: default_address}, opts),
    do: Keyword.get(opts, :to, default_address)
end
