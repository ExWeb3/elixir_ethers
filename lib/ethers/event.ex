defmodule Ethers.Event do
  @moduledoc """
  EVM Event struct and helpers
  """

  alias Ethers.ContractHelpers
  alias Ethers.{Types, Utils}
  alias ABI.{FunctionSelector, TypeDecoder}

  defstruct [
    :address,
    :block_hash,
    :block_number,
    :data_raw,
    :topics,
    :topics_raw,
    :transaction_hash,
    :transaction_index,
    data: [],
    log_index: 0,
    removed: false
  ]

  @type t :: %__MODULE__{
          address: Types.t_address(),
          block_hash: Types.t_hash(),
          block_number: non_neg_integer(),
          topics: [term(), ...],
          topics_raw: [String.t(), ...],
          transaction_hash: Types.t_hash(),
          transaction_index: non_neg_integer(),
          data_raw: String.t(),
          data: [term()],
          log_index: non_neg_integer(),
          removed: boolean()
        }

  @doc """
  Decodes a log entry with the given Event function selector and returns an Event struct
  """
  @spec decode(map(), ABI.FunctionSelector.t()) :: t()
  def decode(log, %ABI.FunctionSelector{} = selector) when is_map(log) do
    data =
      case log do
        %{"data" => "0x"} ->
          []

        %{"data" => raw_data} ->
          data_bin = Utils.hex_decode!(raw_data)
          returns = ContractHelpers.event_non_indexed_types(selector)

          selector
          |> Map.put(:returns, returns)
          |> ABI.decode(data_bin, :output)
          |> Enum.zip(returns)
          |> Enum.map(fn {return, type} -> Utils.human_arg(return, type) end)
      end

    [_ | sub_topics_raw] = topics_raw = Map.fetch!(log, "topics")

    decoded_topics =
      sub_topics_raw
      |> Enum.map(&Utils.hex_decode!/1)
      |> Enum.zip(ContractHelpers.event_indexed_types(selector))
      |> Enum.map(fn
        {data, :string} ->
          {Utils.hex_encode(data), :string}

        {data, type} ->
          [decoded] = TypeDecoder.decode_raw(data, [type])
          {decoded, type}
      end)
      |> Enum.map(fn {data, type} -> Utils.human_arg(data, type) end)

    topics = [FunctionSelector.encode(selector) | decoded_topics]

    {:ok, block_number} = Utils.hex_to_integer(Map.fetch!(log, "blockNumber"))
    {:ok, log_index} = Utils.hex_to_integer(Map.fetch!(log, "logIndex"))
    {:ok, transaction_index} = Utils.hex_to_integer(Map.fetch!(log, "transactionIndex"))

    %__MODULE__{
      address: Map.fetch!(log, "address"),
      block_hash: Map.fetch!(log, "blockHash"),
      block_number: block_number,
      data: data,
      data_raw: Map.fetch!(log, "data"),
      log_index: log_index,
      removed: Map.fetch!(log, "removed"),
      topics: topics,
      topics_raw: topics_raw,
      transaction_hash: Map.fetch!(log, "transactionHash"),
      transaction_index: transaction_index
    }
  end

  @doc """
  Given a log entry and an EventFilters module (e.g. `Ethers.Contracts.ERC20.EventFilters`)
  will find a matching event filter in the given module and decodes the log using the event selector.
  """
  @spec find_and_decode(map(), module()) :: {:ok, t()} | {:error, :not_found}
  def find_and_decode(log, event_filters_module) do
    [topic | _] = Map.fetch!(log, "topics")

    topic_raw = Utils.hex_decode!(topic)

    selector =
      Enum.find(
        event_filters_module.__events__(),
        fn %ABI.FunctionSelector{method_id: method_id} -> method_id == topic_raw end
      )

    case selector do
      nil ->
        {:error, :not_found}

      %ABI.FunctionSelector{} ->
        {:ok, decode(log, selector)}
    end
  end
end
