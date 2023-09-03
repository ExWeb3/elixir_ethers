defmodule Ethers.BlockUtils do
  @moduledoc """
  Utilities functions for looking up blocks and/or block information in EVM chains
  """

  alias Ethers.RPC

  @default_sample_size 10_000
  @default_acceptable_drift 2 * 60

  import Ethers.Utils

  @doc """
  Returns the current block number of the blockchain.
  """
  @spec current_block_number(Keyword.t()) :: {:ok, non_neg_integer()} | {:error, term()}
  def current_block_number(opts \\ []) do
    with {:ok, block_number} <- RPC.eth_block_number(opts) do
      hex_to_integer(block_number)
    end
  end

  @doc """
  Returns the timestamp for a given block number.

  The block_number parameter can be a non negative integer or the hex encoded value of that integer.
  (The hex encoding *must* start with 0x prefix)
  """
  @spec get_block_timestamp(non_neg_integer() | String.t(), Keyword.t()) ::
          {:ok, non_neg_integer()} | {:error, term()}
  def get_block_timestamp(block_number, opts \\ [])

  def get_block_timestamp(block_number, opts) when is_integer(block_number),
    do: get_block_timestamp(integer_to_hex(block_number), opts)

  def get_block_timestamp("0x" <> _ = block_number, opts) do
    with {:ok, block} <- RPC.eth_get_block_by_number(block_number, false, opts) do
      hex_to_integer(Map.fetch!(block, "timestamp"))
    end
  end

  @doc """
  Returns the nearest block number to a given date and time.

  ## Parameters
  - date_or_date_time: Can be a `Date`, `DateTime` or an integer unix timestamp.
  - ref_block_number: A block number of reference. Can help faster search time if given.
  - opts: Optional extra options.
    - acceptable_drift: Can be set to override the default acceptable_drift of #{@default_acceptable_drift} seconds.
    - sample_size: Can be set to override the default sample_size of #{@default_sample_size} blocks.
  """
  @spec date_to_block_number(
          Date.t() | DateTime.t() | non_neg_integer(),
          non_neg_integer() | nil,
          Keyword.t()
        ) :: {:ok, non_neg_integer()} | {:error, term()}
  def date_to_block_number(date_or_date_time, ref_block_number \\ nil, opts \\ [])

  def date_to_block_number(%Date{} = date, ref_block_number, opts) do
    date
    |> DateTime.new!(~T[00:00:00.000], "Etc/UTC")
    |> date_to_block_number(ref_block_number, opts)
  end

  def date_to_block_number(%DateTime{} = datetime, ref_block_number, opts) do
    datetime
    |> DateTime.to_unix()
    |> date_to_block_number(ref_block_number, opts)
  end

  def date_to_block_number(datetime, nil, opts) do
    with {:ok, block_number} <- current_block_number(opts) do
      date_to_block_number(datetime, block_number, opts)
    end
  end

  def date_to_block_number(datetime, ref_block_number, opts) when is_integer(datetime) do
    acceptable_drift = opts[:acceptable_drift] || @default_acceptable_drift

    with {:ok, current_timestamp} <- get_block_timestamp(ref_block_number, opts) do
      if abs(datetime - current_timestamp) <= acceptable_drift do
        {:ok, ref_block_number}
      else
        find_and_try_next_block_number(datetime, ref_block_number, current_timestamp, opts)
      end
    end
  end

  defp find_and_try_next_block_number(datetime, ref_block_number, current_timestamp, opts) do
    sample_size = opts[:sample_size] || @default_sample_size

    with {:ok, old_timestamp} <- get_block_timestamp(ref_block_number - sample_size, opts) do
      avg_time = (current_timestamp - old_timestamp) / (sample_size + 1)

      new_block_number = ref_block_number - round((current_timestamp - datetime) / avg_time)

      date_to_block_number(datetime, new_block_number, opts)
    end
  end
end
