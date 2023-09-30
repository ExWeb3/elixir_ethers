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

          ABI.decode(selector, data_bin, :output)
          |> Enum.zip(selector.returns)
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
end
