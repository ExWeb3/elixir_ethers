defmodule Ethers.Contract.Test.StateOverrideCounterContract do
  @moduledoc false
  use Ethers.Contract, abi_file: "tmp/counter_abi.json"
end

defmodule Ethers.StateOverrideTest do
  use ExUnit.Case
  doctest Ethers.StateOverride

  import Ethers.TestHelpers

  alias Ethers.Contract.Test.StateOverrideCounterContract, as: CounterContract
  alias Ethers.StateOverride
  alias Ethers.Utils

  @from "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
  # An address nothing is deployed to and nobody funds
  @empty_address "0x1111111111111111111111111111111111111111"

  describe "to_rpc_map/1" do
    test "encodes quantities, code and storage words" do
      code = Ethers.Utils.hex_decode!("0x60016000f3")

      assert {:ok,
              %{
                @empty_address => %{
                  balance: "0xDE0B6B3A7640000",
                  nonce: "0x7",
                  code: "0x60016000f3",
                  stateDiff: state_diff
                }
              }} =
               StateOverride.to_rpc_map(%{
                 @empty_address => %{
                   balance: 1_000_000_000_000_000_000,
                   nonce: 7,
                   code: code,
                   state_diff: %{0 => 42}
                 }
               })

      assert state_diff == %{
               ("0x" <> String.duplicate("0", 64)) => "0x" <> String.duplicate("0", 62) <> "2a"
             }
    end

    test "accepts binary addresses and hex quantities" do
      address_bin = Utils.hex_decode!(@empty_address)

      assert {:ok, %{@empty_address => %{balance: "0x1234"}}} ==
               StateOverride.to_rpc_map(%{address_bin => %{balance: "0x1234"}})
    end

    test "encodes full state replacement with padded hex slots" do
      assert {:ok, %{@empty_address => %{state: state}}} =
               StateOverride.to_rpc_map(%{@empty_address => %{state: %{"0x1" => "0xff"}}})

      assert state == %{
               ("0x" <> String.duplicate("0", 63) <> "1") =>
                 "0x" <> String.duplicate("0", 62) <> "ff"
             }
    end

    test "rejects invalid addresses" do
      assert {:error, {:invalid_address, "0xinvalid"}} =
               StateOverride.to_rpc_map(%{"0xinvalid" => %{balance: 1}})

      assert {:error, {:invalid_address, :bad}} = StateOverride.to_rpc_map(%{bad: %{balance: 1}})
    end

    test "rejects unknown account override keys and invalid values" do
      assert {:error, {:invalid_account_override, {:storage, _}}} =
               StateOverride.to_rpc_map(%{@empty_address => %{storage: %{}}})

      assert {:error, {:invalid_account_override, {:balance, -1}}} =
               StateOverride.to_rpc_map(%{@empty_address => %{balance: -1}})

      assert {:error, {:invalid_account_override, {:state_diff, {:invalid_storage_word, _}}}} =
               StateOverride.to_rpc_map(%{@empty_address => %{state_diff: %{"bad" => 1}}})
    end

    test "rejects mixing state and state_diff for the same account" do
      assert {:error, :state_and_state_diff_exclusive} =
               StateOverride.to_rpc_map(%{
                 @empty_address => %{state: %{0 => 1}, state_diff: %{0 => 1}}
               })
    end

    test "rejects non-map inputs" do
      assert {:error, :invalid_state_overrides} = StateOverride.to_rpc_map([])

      assert {:error, {:invalid_account_override, nil}} =
               StateOverride.to_rpc_map(%{@empty_address => nil})
    end
  end

  describe "Ethers.call/2 with state overrides" do
    setup :deploy_counter_contract

    test "state_diff overrides a single storage slot", %{address: address} do
      assert {:ok, 100} = CounterContract.get() |> Ethers.call(to: address)

      assert {:ok, 424_242} =
               CounterContract.get()
               |> Ethers.call(
                 to: address,
                 state_overrides: %{address => %{state_diff: %{0 => 424_242}}}
               )

      # The override never touches the actual chain state
      assert {:ok, 100} = CounterContract.get() |> Ethers.call(to: address)
    end

    test "code override runs a contract at an address with no code", %{address: address} do
      {:ok, code} = Ethereumex.HttpClient.eth_get_code(String.downcase(address), "latest")

      assert {:error, _} = CounterContract.get() |> Ethers.call(to: @empty_address)

      assert {:ok, 0} =
               CounterContract.get()
               |> Ethers.call(
                 to: @empty_address,
                 state_overrides: %{@empty_address => %{code: code}}
               )

      assert {:ok, 5} =
               CounterContract.get()
               |> Ethers.call(
                 to: @empty_address,
                 state_overrides: %{@empty_address => %{code: code, state_diff: %{0 => 5}}}
               )
    end

    test "returns encoding errors without hitting the RPC", %{address: address} do
      assert {:error, {:invalid_address, "0xinvalid"}} =
               CounterContract.get()
               |> Ethers.call(to: address, state_overrides: %{"0xinvalid" => %{balance: 1}})
    end

    test "returns error when the RPC client does not support state overrides", %{
      address: address
    } do
      assert {:error, :state_overrides_not_supported} =
               CounterContract.get()
               |> Ethers.call(
                 to: address,
                 rpc_client: Ethers.TestRPCModule,
                 state_overrides: %{address => %{state_diff: %{0 => 1}}}
               )
    end

    test "is rejected in batch requests", %{address: address} do
      assert {:error, :state_overrides_not_supported_in_batch} =
               Ethers.batch([
                 {:call, CounterContract.get(),
                  [to: address, state_overrides: %{address => %{state_diff: %{0 => 1}}}]}
               ])
    end
  end

  describe "Ethers.estimate_gas/2 with state overrides" do
    setup :deploy_counter_contract

    test "code override changes the gas estimate", %{address: address} do
      {:ok, code} = Ethereumex.HttpClient.eth_get_code(String.downcase(address), "latest")

      set_call = CounterContract.set(842)

      # Without the override the target has no code, so this is priced as a plain transfer
      assert {:ok, base_gas} = Ethers.estimate_gas(set_call, to: @empty_address, from: @from)

      assert {:ok, override_gas} =
               Ethers.estimate_gas(set_call,
                 to: @empty_address,
                 from: @from,
                 state_overrides: %{@empty_address => %{code: code}}
               )

      # With the counter code injected the call executes an SSTORE and costs more
      assert override_gas > base_gas
    end

    test "balance override funds an empty sender" do
      params = %{from: @empty_address, to: @from, value: Utils.to_wei(1)}

      assert {:ok, 21_000} =
               Ethers.estimate_gas(params,
                 state_overrides: %{@empty_address => %{balance: Utils.to_wei(10)}}
               )
    end

    test "returns error when the RPC client does not support state overrides", %{
      address: address
    } do
      assert {:error, :state_overrides_not_supported} =
               CounterContract.set(1)
               |> Ethers.estimate_gas(
                 to: address,
                 from: @from,
                 rpc_client: Ethers.TestRPCModule,
                 state_overrides: %{address => %{state_diff: %{0 => 1}}}
               )
    end
  end

  defp deploy_counter_contract(_ctx) do
    address =
      deploy(CounterContract,
        encoded_constructor: CounterContract.constructor(100),
        from: @from
      )

    [address: address]
  end
end
