defmodule Ethers.FeeEstimationTest.FeeHistoryRPC do
  @moduledoc false
  # Returns a fixed eth_feeHistory response so the estimation math can be verified.
  # Next block base fee (last entry) is 0xa0 = 160, rewards have a median of 0x3 = 3.

  def eth_fee_history(block_count, newest_block, [percentile], opts) do
    if pid = opts[:send_params_to_pid] do
      send(pid, {:fee_history_params, block_count, newest_block, percentile})
    end

    reward =
      if opts[:empty_rewards] do
        [[], [], [], [], []]
      else
        [["0x1"], ["0x5"], ["0x3"], ["0x2"], ["0x4"]]
      end

    {:ok,
     %{
       "oldestBlock" => "0x1",
       "baseFeePerGas" => ["0x64", "0x6e", "0x78", "0x82", "0x8c", "0xa0"],
       "gasUsedRatio" => [0.1, 0.2, 0.3, 0.4, 0.5],
       "reward" => reward
     }}
  end
end

defmodule Ethers.FeeEstimationTest.LegacyOnlyRPC do
  @moduledoc false
  # An RPC client without eth_feeHistory support - auto-fill must fall back to the
  # legacy gas price based estimation.

  def batch_request(requests, _opts) do
    {:ok,
     Enum.map(requests, fn
       {:eth_gas_price, []} -> {:ok, "0x100"}
       {:eth_max_priority_fee_per_gas, []} -> {:ok, "0x10"}
     end)}
  end
end

defmodule Ethers.FeeEstimationTest do
  use ExUnit.Case

  alias Ethers.FeeEstimationTest.FeeHistoryRPC
  alias Ethers.FeeEstimationTest.LegacyOnlyRPC
  alias Ethers.Transaction
  alias Ethers.Transaction.Eip1559

  @from "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
  @to "0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc"

  describe "fee_history/4" do
    test "returns decoded fee history" do
      assert {:ok, fee_history} = Ethers.fee_history(3, "latest", [50])

      assert is_integer(fee_history.oldest_block)
      assert Enum.all?(fee_history.base_fee_per_gas, &is_integer/1)
      # One extra entry: the expected base fee of the next block
      assert length(fee_history.base_fee_per_gas) == length(fee_history.gas_used_ratio) + 1
      assert Enum.all?(fee_history.reward, fn [reward] -> is_integer(reward) end)
    end

    test "returns no reward data when no percentiles are requested" do
      assert {:ok, %{reward: reward}} = Ethers.fee_history(2)

      # Geth omits the reward field entirely, anvil returns an empty list
      assert reward in [nil, []]
    end

    test "accepts an integer newest block" do
      {:ok, block_number} = Ethers.current_block_number()

      assert {:ok, %{oldest_block: oldest_block}} = Ethers.fee_history(2, block_number, [50])
      assert oldest_block == block_number - 1
    end

    test "works in batch requests" do
      assert {:ok, [{:ok, %{base_fee_per_gas: [_ | _]}}, {:ok, gas_price}]} =
               Ethers.batch([{:fee_history, [2, "latest", [50]]}, :current_gas_price])

      assert is_integer(gas_price)
    end

    test "returns error for invalid params" do
      assert {:error, :invalid_fee_history_params} = Ethers.fee_history(2, "latest", 50)
      assert {:error, :invalid_fee_history_params} = Ethers.fee_history(0, "latest", [50])
    end

    test "returns error when the RPC client does not support eth_feeHistory" do
      assert {:error, :not_supported} =
               Ethers.fee_history(2, "latest", [50], rpc_client: Ethers.TestRPCModule)

      # estimate_fees propagates the error instead of raising
      assert {:error, :not_supported} = Ethers.estimate_fees(rpc_client: Ethers.TestRPCModule)
    end

    test "accepts only one representation per input - no hex encoded quantities" do
      # Quantities are integers and the newest block is an integer or a named block tag.
      # Hex encoded strings are rejected instead of being passed through.
      assert {:error, :invalid_fee_history_params} = Ethers.fee_history("0x2", "latest", [50])
      assert {:error, :invalid_fee_history_params} = Ethers.fee_history(2, "0x10", [50])
      assert {:error, :invalid_fee_history_params} = Ethers.fee_history(2, "newest", [50])
    end

    test "bang version returns unwrapped value and raises on error" do
      assert %{base_fee_per_gas: [_ | _]} = Ethers.fee_history!(2, "latest", [50])

      assert_raise Ethers.ExecutionError, fn ->
        Ethers.fee_history!(2, "latest", 50)
      end
    end
  end

  describe "estimate_fees/1" do
    test "estimates max fee and max priority fee from fee history" do
      # median(1, 5, 3, 2, 4) = 3 and next block base fee = 160:
      # max_fee_per_gas = 2 * 160 + 3
      assert {:ok, %{max_fee_per_gas: 323, max_priority_fee_per_gas: 3}} ==
               Ethers.estimate_fees(rpc_client: FeeHistoryRPC)
    end

    test "samples the percentile matching the requested speed" do
      opts = [rpc_client: FeeHistoryRPC, rpc_opts: [send_params_to_pid: self()]]

      {:ok, _fees} = Ethers.estimate_fees(opts)
      assert_received {:fee_history_params, "0xA", "latest", 50}

      {:ok, _fees} = Ethers.estimate_fees([speed: :slow] ++ opts)
      assert_received {:fee_history_params, "0xA", "latest", 25}

      {:ok, _fees} = Ethers.estimate_fees([speed: :fast, block_count: 4] ++ opts)
      assert_received {:fee_history_params, "0x4", "latest", 75}

      {:ok, _fees} = Ethers.estimate_fees([speed: 90] ++ opts)
      assert_received {:fee_history_params, "0xA", "latest", 90}
    end

    test "returns error for invalid speed" do
      assert {:error, :invalid_speed} = Ethers.estimate_fees(speed: :warp)
      assert {:error, :invalid_speed} = Ethers.estimate_fees(speed: 101)
    end

    test "returns error when the node reports no rewards" do
      assert {:error, :no_fee_history_data} =
               Ethers.estimate_fees(rpc_client: FeeHistoryRPC, rpc_opts: [empty_rewards: true])
    end

    test "works against a real node" do
      assert {:ok, %{max_fee_per_gas: max_fee, max_priority_fee_per_gas: max_priority_fee}} =
               Ethers.estimate_fees()

      assert is_integer(max_fee) and is_integer(max_priority_fee)
      assert max_fee > max_priority_fee
    end

    test "bang version returns unwrapped value and raises on error" do
      assert %{max_fee_per_gas: 323} = Ethers.estimate_fees!(rpc_client: FeeHistoryRPC)

      assert_raise Ethers.ExecutionError, fn ->
        Ethers.estimate_fees!(speed: :warp)
      end
    end
  end

  describe "transaction auto-fill" do
    test "fills missing fees from fee history" do
      params = %{type: Eip1559, chain_id: 1, nonce: 1, gas: 21_000}

      assert {:ok, filled} =
               Transaction.add_auto_fetchable_fields(params, rpc_client: FeeHistoryRPC)

      assert %{max_fee_per_gas: 323, max_priority_fee_per_gas: 3} = filled
    end

    test "only fills the missing fee fields" do
      params = %{type: Eip1559, chain_id: 1, nonce: 1, gas: 21_000, max_priority_fee_per_gas: 7}

      assert {:ok, filled} =
               Transaction.add_auto_fetchable_fields(params, rpc_client: FeeHistoryRPC)

      assert %{max_fee_per_gas: 323, max_priority_fee_per_gas: 7} = filled
    end

    test "falls back to gas price estimation without eth_feeHistory support" do
      params = %{type: Eip1559, chain_id: 1, nonce: 1, gas: 21_000}

      assert {:ok, filled} =
               Transaction.add_auto_fetchable_fields(params, rpc_client: LegacyOnlyRPC)

      # 120% margin over the 0x100 gas price, and the plain 0x10 priority fee
      assert %{max_fee_per_gas: 307, max_priority_fee_per_gas: 16} = filled
    end

    test "fills all auto-fetchable fields against a real node" do
      params = %{type: Eip1559, from: @from, to: @to, value: 1}

      assert {:ok, filled} = Transaction.add_auto_fetchable_fields(params, [])

      assert is_integer(filled.chain_id)
      assert is_integer(filled.nonce)
      assert is_integer(filled.gas)
      assert is_integer(filled.max_fee_per_gas)
      assert is_integer(filled.max_priority_fee_per_gas)
      assert filled.max_fee_per_gas > filled.max_priority_fee_per_gas
    end
  end
end
