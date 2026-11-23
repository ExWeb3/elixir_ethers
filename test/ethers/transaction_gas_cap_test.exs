defmodule Ethers.TransactionGasCapTest.StubRPC do
  @moduledoc false
  # Answers eth_estimateGas with the `:estimate` given in the rpc_opts and reports the params of
  # every request to the calling (test) process.

  @tx_hash "0x" <> String.duplicate("ab", 32)

  def batch_request(requests, opts) do
    results =
      Enum.map(requests, fn {method, params} -> apply(__MODULE__, method, params ++ [opts]) end)

    {:ok, results}
  end

  def eth_estimate_gas(params, opts) do
    send(self(), {:eth_estimate_gas, params})
    {:ok, Ethers.Utils.integer_to_hex(Keyword.fetch!(opts, :estimate))}
  end

  def eth_get_transaction_count(address, _block, _opts) do
    send(self(), {:eth_get_transaction_count, address})
    {:ok, "0x0"}
  end

  def eth_call(params, _block, _opts) do
    send(self(), {:eth_call, params})
    # decimals() => 18
    {:ok, "0x" <> String.pad_leading("12", 64, "0")}
  end

  def eth_send_transaction(params, _opts) do
    send(self(), {:eth_send_transaction, params})
    {:ok, @tx_hash}
  end

  def eth_send_raw_transaction(raw_transaction, _opts) do
    send(self(), {:eth_send_raw_transaction, raw_transaction})
    {:ok, @tx_hash}
  end
end

defmodule Ethers.TransactionGasCapTest do
  # Not async: changes the :max_transaction_gas application env
  use ExUnit.Case

  import ExUnit.CaptureLog

  alias Ethers.Contracts.ERC20
  alias Ethers.Transaction
  alias Ethers.Transaction.Eip1559
  alias Ethers.TransactionGasCapTest.StubRPC

  @eip7825_cap 16_777_216
  @warning "exceeds the EIP-7825 per-transaction gas limit cap of 16777216"

  @from "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
  @from_private_key "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
  @to "0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc"

  # Everything but gas, so auto-fill only calls eth_estimateGas
  @params %{
    type: Eip1559,
    from: @from,
    to: @to,
    value: 1,
    chain_id: 31_337,
    nonce: 0,
    max_fee_per_gas: 1_000_000_000,
    max_priority_fee_per_gas: 1_000_000
  }

  @sign_opts [
    signer: Ethers.Signer.Local,
    signer_opts: [private_key: @from_private_key],
    rpc_client: StubRPC
  ]

  setup do
    previous = Application.fetch_env(:ethers, :max_transaction_gas)

    on_exit(fn ->
      case previous do
        {:ok, value} -> Application.put_env(:ethers, :max_transaction_gas, value)
        :error -> Application.delete_env(:ethers, :max_transaction_gas)
      end
    end)
  end

  defp put_max_transaction_gas(value),
    do: Application.put_env(:ethers, :max_transaction_gas, value)

  defp auto_fill(params, estimate, opts \\ []) do
    Transaction.add_auto_fetchable_fields(
      params,
      [rpc_client: StubRPC, rpc_opts: [estimate: estimate]] ++ opts
    )
  end

  defp warnings(log), do: log |> String.split(@warning) |> length() |> Kernel.-(1)

  describe "auto-filled gas without a configured cap" do
    test "applies the margin" do
      assert {{:ok, %{gas: 1_100_000}}, ""} = with_log(fn -> auto_fill(@params, 1_000_000) end)
    end

    test "is not clamped to the EIP-7825 cap and logs a warning" do
      {result, log} = with_log(fn -> auto_fill(@params, 16_000_000) end)

      assert {:ok, %{gas: 17_600_000}} = result
      assert log =~ "Transaction gas limit 17600000 #{@warning}"
      assert log =~ "max_transaction_gas"
    end

    test "treats a nil config as not configured" do
      put_max_transaction_gas(nil)

      {result, log} = with_log(fn -> auto_fill(@params, 16_000_000) end)

      assert {:ok, %{gas: 17_600_000}} = result
      assert log =~ @warning
    end
  end

  describe "auto-filled gas with a configured cap" do
    setup do
      put_max_transaction_gas(@eip7825_cap)
    end

    test "applies the margin below the cap" do
      assert {{:ok, %{gas: 1_100_000}}, ""} = with_log(fn -> auto_fill(@params, 1_000_000) end)
    end

    test "clamps the margin to the cap" do
      assert {{:ok, %{gas: @eip7825_cap}}, ""} =
               with_log(fn -> auto_fill(@params, 16_000_000) end)
    end

    test "accepts an estimate exactly at the cap" do
      assert {{:ok, %{gas: @eip7825_cap}}, ""} =
               with_log(fn -> auto_fill(@params, @eip7825_cap) end)
    end

    test "returns an error for an estimate above the cap" do
      assert {{:error, :gas_limit_exceeds_cap}, ""} =
               with_log(fn -> auto_fill(@params, @eip7825_cap + 1) end)
    end

    test "uses a custom cap" do
      put_max_transaction_gas(30_000_000)

      assert {:ok, %{gas: 22_000_000}} = auto_fill(@params, 20_000_000)
      assert {:ok, %{gas: 30_000_000}} = auto_fill(@params, 28_000_000)
      assert {:error, :gas_limit_exceeds_cap} = auto_fill(@params, 30_000_001)
    end
  end

  describe "auto-filled gas with the cap disabled" do
    test "is not clamped and logs nothing" do
      put_max_transaction_gas(false)

      assert {{:ok, %{gas: 17_600_000}}, ""} =
               with_log(fn -> auto_fill(@params, 16_000_000) end)

      assert {:ok, %{gas: 110_000_000}} = auto_fill(@params, 100_000_000)
    end
  end

  describe "explicit gas" do
    test "is checked before fetching missing fields" do
      put_max_transaction_gas(@eip7825_cap)
      params = @params |> Map.delete(:nonce) |> Map.put(:gas, @eip7825_cap + 1)

      assert {:error, :gas_limit_exceeds_cap} = auto_fill(params, 1_000_000)
      refute_received {:eth_get_transaction_count, _address}

      assert {:ok, %{nonce: 0}} = auto_fill(Map.put(params, :gas, @eip7825_cap), 1_000_000)
      assert_received {:eth_get_transaction_count, @from}
    end

    test "is never altered" do
      put_max_transaction_gas(@eip7825_cap)

      for gas <- [21_000, @eip7825_cap] do
        assert {:ok, %{gas: ^gas}} = auto_fill(Map.put(@params, :gas, gas), 1_000_000)
      end
    end

    test "above the EIP-7825 cap logs a warning without a configured cap" do
      params = Map.put(@params, :gas, 20_000_000)

      {result, log} = with_log(fn -> auto_fill(params, 1_000_000) end)

      assert {:ok, %{gas: 20_000_000}} = result
      assert log =~ "Transaction gas limit 20000000 #{@warning}"
    end

    test "above the EIP-7825 cap logs nothing with the cap disabled" do
      put_max_transaction_gas(false)
      params = Map.put(@params, :gas, 20_000_000)

      assert {{:ok, %{gas: 20_000_000}}, ""} = with_log(fn -> auto_fill(params, 1_000_000) end)
    end
  end

  describe "max_transaction_gas option" do
    test "takes precedence over the config" do
      params = Map.put(@params, :gas, 20_000_000)

      put_max_transaction_gas(@eip7825_cap)

      assert {{:ok, %{gas: 20_000_000}}, ""} =
               with_log(fn -> auto_fill(params, 1, max_transaction_gas: 30_000_000) end)

      assert {{:ok, %{gas: 20_000_000}}, ""} =
               with_log(fn -> auto_fill(params, 1, max_transaction_gas: false) end)

      put_max_transaction_gas(false)

      assert {{:error, :gas_limit_exceeds_cap}, ""} =
               with_log(fn -> auto_fill(params, 1, max_transaction_gas: @eip7825_cap) end)
    end

    test "falls back to the config when nil" do
      put_max_transaction_gas(@eip7825_cap)

      assert {:ok, %{gas: @eip7825_cap}} =
               auto_fill(@params, 16_000_000, max_transaction_gas: nil)
    end

    test "raises on invalid values" do
      for invalid <- [0, -1, true, "16777216"] do
        assert_raise ArgumentError, ~r/Invalid :max_transaction_gas/, fn ->
          auto_fill(@params, 1_000_000, max_transaction_gas: invalid)
        end
      end
    end
  end

  describe "Ethers.sign_transaction/2" do
    test "auto-fills gas above the EIP-7825 cap with a single warning" do
      overrides = [rpc_opts: [estimate: 16_000_000]] ++ @sign_opts

      {result, log} = with_log(fn -> Ethers.sign_transaction(@params, overrides) end)

      assert {:ok, signed_transaction} = result

      assert {:ok, %Transaction.Signed{payload: %Eip1559{gas: 17_600_000}}} =
               Transaction.decode(signed_transaction)

      assert warnings(log) == 1
    end

    test "clamps the auto-filled gas to the max_transaction_gas option" do
      overrides =
        [rpc_opts: [estimate: 16_000_000], max_transaction_gas: @eip7825_cap] ++ @sign_opts

      assert {{:ok, signed_transaction}, ""} =
               with_log(fn -> Ethers.sign_transaction(@params, overrides) end)

      assert {:ok, %Transaction.Signed{payload: %Eip1559{gas: @eip7825_cap}}} =
               Transaction.decode(signed_transaction)
    end

    test "returns an error for explicit gas above the max_transaction_gas option" do
      overrides = [gas: @eip7825_cap + 1, max_transaction_gas: @eip7825_cap] ++ @sign_opts

      assert {:error, :gas_limit_exceeds_cap} = Ethers.sign_transaction(@params, overrides)

      assert_raise Ethers.ExecutionError, fn ->
        Ethers.sign_transaction!(@params, overrides)
      end
    end
  end

  describe "Ethers.send_transaction/2" do
    test "checks explicit gas when the node signs the transaction" do
      params = Map.put(@params, :gas, @eip7825_cap + 1)

      assert {:error, :gas_limit_exceeds_cap} =
               Ethers.send_transaction(params,
                 rpc_client: StubRPC,
                 max_transaction_gas: @eip7825_cap
               )

      refute_received {:eth_send_transaction, _params}

      {result, log} = with_log(fn -> Ethers.send_transaction(params, rpc_client: StubRPC) end)

      assert {:ok, _tx_hash} = result
      assert warnings(log) == 1
    end

    test "does not send the max_transaction_gas option to the node" do
      assert {:ok, _tx_hash} =
               Ethers.send_transaction(@params,
                 rpc_client: StubRPC,
                 max_transaction_gas: @eip7825_cap
               )

      assert_received {:eth_send_transaction, params}
      refute Map.has_key?(params, :max_transaction_gas)
      refute Map.has_key?(params, :gas)
    end

    test "checks the gas of transactions signed with a signer" do
      overrides = [
        signer: Ethers.Signer.Local,
        signer_opts: [private_key: @from_private_key],
        rpc_client: StubRPC,
        rpc_opts: [estimate: @eip7825_cap + 1],
        max_transaction_gas: @eip7825_cap
      ]

      assert {:error, :gas_limit_exceeds_cap} = Ethers.send_transaction(@params, overrides)
      refute_received {:eth_send_raw_transaction, _raw_transaction}

      overrides = Keyword.put(overrides, :rpc_opts, estimate: 21_000)

      assert {:ok, _tx_hash} = Ethers.send_transaction(@params, overrides)
      assert_received {:eth_send_raw_transaction, _raw_transaction}
    end
  end

  describe "Ethers.deploy/2" do
    test "checks explicit gas" do
      overrides = [from: @from, gas: @eip7825_cap + 1, rpc_client: StubRPC]

      assert {:error, :gas_limit_exceeds_cap} =
               Ethers.deploy(<<0x60, 0x00>>, [max_transaction_gas: @eip7825_cap] ++ overrides)

      assert {:ok, _tx_hash} =
               Ethers.deploy(<<0x60, 0x00>>, [max_transaction_gas: false] ++ overrides)

      assert_received {:eth_send_transaction, params}
      refute Map.has_key?(params, :max_transaction_gas)
    end
  end

  describe "Ethers.batch/2" do
    test "checks send_transaction requests with the max_transaction_gas option" do
      over_cap = Map.put(@params, :gas, @eip7825_cap + 1)
      within_cap = Map.put(@params, :gas, 21_000)

      assert {:error, :gas_limit_exceeds_cap} =
               Ethers.batch(
                 [{:send_transaction, over_cap, max_transaction_gas: @eip7825_cap}],
                 rpc_client: StubRPC
               )

      assert {:error, :gas_limit_exceeds_cap} =
               Ethers.batch([{:send_transaction, over_cap}],
                 rpc_client: StubRPC,
                 max_transaction_gas: @eip7825_cap
               )

      assert {:ok, [ok: _tx_hash]} =
               Ethers.batch(
                 [{:send_transaction, within_cap, max_transaction_gas: @eip7825_cap}],
                 rpc_client: StubRPC
               )

      assert_received {:eth_send_transaction, params}
      refute Map.has_key?(params, :max_transaction_gas)
    end
  end

  describe "simulations" do
    setup do
      put_max_transaction_gas(@eip7825_cap)
    end

    test "Ethers.estimate_gas/2 is not affected" do
      overrides = [
        gas: 30_000_000,
        max_transaction_gas: 1_000_000,
        rpc_client: StubRPC,
        rpc_opts: [estimate: 20_000_000]
      ]

      assert {{:ok, 20_000_000}, ""} =
               with_log(fn -> Ethers.estimate_gas(%{from: @from, to: @to}, overrides) end)

      assert_received {:eth_estimate_gas, params}
      assert params.gas == Ethers.Utils.integer_to_hex(30_000_000)
      refute Map.has_key?(params, :max_transaction_gas)
    end

    test "Ethers.call/2 is not affected" do
      overrides = [to: @to, gas: 30_000_000, max_transaction_gas: 1_000_000, rpc_client: StubRPC]

      assert {{:ok, 18}, ""} = with_log(fn -> Ethers.call(ERC20.decimals(), overrides) end)

      assert_received {:eth_call, params}
      assert params.gas == Ethers.Utils.integer_to_hex(30_000_000)
      refute Map.has_key?(params, :max_transaction_gas)
    end
  end
end
