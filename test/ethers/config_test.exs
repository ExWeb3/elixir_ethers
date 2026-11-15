defmodule Ethers.ConfigTest.Fixtures do
  @moduledoc false
  # Sample configs from EIP-7910 ("Test Cases" > "Sample Configs"), verbatim.

  @hoodi_cancun ~S"""
  {
    "activationTime": 0,
    "blobSchedule": {
      "baseFeeUpdateFraction": 3338477,
      "max": 6,
      "target": 3
    },
    "chainId": "0x88bb0",
    "forkId": "0xbef71d30",
    "precompiles": {
      "BLAKE2F": "0x0000000000000000000000000000000000000009",
      "BN254_ADD": "0x0000000000000000000000000000000000000006",
      "BN254_MUL": "0x0000000000000000000000000000000000000007",
      "BN254_PAIRING": "0x0000000000000000000000000000000000000008",
      "ECREC": "0x0000000000000000000000000000000000000001",
      "ID": "0x0000000000000000000000000000000000000004",
      "KZG_POINT_EVALUATION": "0x000000000000000000000000000000000000000a",
      "MODEXP": "0x0000000000000000000000000000000000000005",
      "RIPEMD160": "0x0000000000000000000000000000000000000003",
      "SHA256": "0x0000000000000000000000000000000000000002"
    },
    "systemContracts": {
      "BEACON_ROOTS_ADDRESS": "0x000f3df6d732807ef1319fb7b8bb8522d0beac02"
    }
  }
  """

  @hoodi_prague ~S"""
  {
    "activationTime": 1742999832,
    "blobSchedule": {
      "baseFeeUpdateFraction": 5007716,
      "max": 9,
      "target": 6
    },
    "chainId": "0x88bb0",
    "forkId": "0x0929e24e",
    "precompiles": {
      "BLAKE2F": "0x0000000000000000000000000000000000000009",
      "BLS12_G1ADD": "0x000000000000000000000000000000000000000b",
      "BLS12_G1MSM": "0x000000000000000000000000000000000000000c",
      "BLS12_G2ADD": "0x000000000000000000000000000000000000000d",
      "BLS12_G2MSM": "0x000000000000000000000000000000000000000e",
      "BLS12_MAP_FP2_TO_G2": "0x0000000000000000000000000000000000000011",
      "BLS12_MAP_FP_TO_G1": "0x0000000000000000000000000000000000000010",
      "BLS12_PAIRING_CHECK": "0x000000000000000000000000000000000000000f",
      "BN254_ADD": "0x0000000000000000000000000000000000000006",
      "BN254_MUL": "0x0000000000000000000000000000000000000007",
      "BN254_PAIRING": "0x0000000000000000000000000000000000000008",
      "ECREC": "0x0000000000000000000000000000000000000001",
      "ID": "0x0000000000000000000000000000000000000004",
      "KZG_POINT_EVALUATION": "0x000000000000000000000000000000000000000a",
      "MODEXP": "0x0000000000000000000000000000000000000005",
      "RIPEMD160": "0x0000000000000000000000000000000000000003",
      "SHA256": "0x0000000000000000000000000000000000000002"
    },
    "systemContracts": {
      "BEACON_ROOTS_ADDRESS": "0x000f3df6d732807ef1319fb7b8bb8522d0beac02",
      "CONSOLIDATION_REQUEST_PREDEPLOY_ADDRESS": "0x0000bbddc7ce488642fb579f8b00f3a590007251",
      "DEPOSIT_CONTRACT_ADDRESS": "0x00000000219ab540356cbb839cbe05303d7705fa",
      "HISTORY_STORAGE_ADDRESS": "0x0000f90827f1c53a10cb7a02335b175320002935",
      "WITHDRAWAL_REQUEST_PREDEPLOY_ADDRESS": "0x00000961ef480eb55e80d19ad83579a64c007002"
    }
  }
  """

  def hoodi_cancun, do: Jason.decode!(@hoodi_cancun)
  def hoodi_prague, do: Jason.decode!(@hoodi_prague)

  # EIP-7910 sample JSON-RPC result "With Future Fork Scheduled" (Hoodi before Prague)
  def future_fork_scheduled,
    do: %{"current" => hoodi_cancun(), "next" => hoodi_prague(), "last" => hoodi_prague()}

  # EIP-7910 sample JSON-RPC result "Without Future Fork Scheduled"
  def no_future_fork, do: %{"current" => hoodi_cancun(), "next" => nil, "last" => nil}
end

defmodule Ethers.ConfigTest.ConfigRPC do
  @moduledoc false
  # Returns the eth_config response given in the `:response` rpc option (defaults to the
  # EIP-7910 sample result with a future fork scheduled).

  alias Ethers.ConfigTest.Fixtures

  def eth_config(opts) do
    if pid = opts[:send_params_to_pid] do
      send(pid, :eth_config)
    end

    Keyword.get(opts, :response, {:ok, Fixtures.future_fork_scheduled()})
  end

  def batch_request(requests, opts) do
    if pid = opts[:send_params_to_pid] do
      send(pid, {:batch_request, requests})
    end

    {:ok,
     Enum.map(requests, fn
       {:eth_config, []} -> {:ok, Fixtures.no_future_fork()}
       {:eth_chain_id, []} -> {:ok, "0x88bb0"}
     end)}
  end
end

defmodule Ethers.ConfigTest do
  use ExUnit.Case

  alias Ethers.ConfigTest.ConfigRPC
  alias Ethers.ConfigTest.Fixtures

  @hoodi_chain_id 560_048

  @cancun_precompiles %{
    "BLAKE2F" => "0x0000000000000000000000000000000000000009",
    "BN254_ADD" => "0x0000000000000000000000000000000000000006",
    "BN254_MUL" => "0x0000000000000000000000000000000000000007",
    "BN254_PAIRING" => "0x0000000000000000000000000000000000000008",
    "ECREC" => "0x0000000000000000000000000000000000000001",
    "ID" => "0x0000000000000000000000000000000000000004",
    "KZG_POINT_EVALUATION" => "0x000000000000000000000000000000000000000A",
    "MODEXP" => "0x0000000000000000000000000000000000000005",
    "RIPEMD160" => "0x0000000000000000000000000000000000000003",
    "SHA256" => "0x0000000000000000000000000000000000000002"
  }

  @prague_precompiles Map.merge(@cancun_precompiles, %{
                        "BLS12_G1ADD" => "0x000000000000000000000000000000000000000b",
                        "BLS12_G1MSM" => "0x000000000000000000000000000000000000000C",
                        "BLS12_G2ADD" => "0x000000000000000000000000000000000000000d",
                        "BLS12_G2MSM" => "0x000000000000000000000000000000000000000E",
                        "BLS12_MAP_FP2_TO_G2" => "0x0000000000000000000000000000000000000011",
                        "BLS12_MAP_FP_TO_G1" => "0x0000000000000000000000000000000000000010",
                        "BLS12_PAIRING_CHECK" => "0x000000000000000000000000000000000000000F"
                      })

  @hoodi_cancun %{
    activation_time: 0,
    blob_schedule: %{base_fee_update_fraction: 3_338_477, max: 6, target: 3},
    chain_id: @hoodi_chain_id,
    fork_id: "0xbef71d30",
    precompiles: @cancun_precompiles,
    system_contracts: %{
      "BEACON_ROOTS_ADDRESS" => "0x000F3df6D732807Ef1319fB7B8bB8522d0Beac02"
    }
  }

  @hoodi_prague %{
    activation_time: 1_742_999_832,
    blob_schedule: %{base_fee_update_fraction: 5_007_716, max: 9, target: 6},
    chain_id: @hoodi_chain_id,
    fork_id: "0x0929e24e",
    precompiles: @prague_precompiles,
    system_contracts: %{
      "BEACON_ROOTS_ADDRESS" => "0x000F3df6D732807Ef1319fB7B8bB8522d0Beac02",
      "CONSOLIDATION_REQUEST_PREDEPLOY_ADDRESS" => "0x0000BBdDc7CE488642fb579F8B00f3a590007251",
      "DEPOSIT_CONTRACT_ADDRESS" => "0x00000000219ab540356cBB839Cbe05303d7705Fa",
      "HISTORY_STORAGE_ADDRESS" => "0x0000F90827F1C53a10cb7A02335B175320002935",
      "WITHDRAWAL_REQUEST_PREDEPLOY_ADDRESS" => "0x00000961Ef480Eb55e80D19ad83579A64c007002"
    }
  }

  describe "config/1" do
    test "decodes the EIP-7910 sample response with a future fork scheduled" do
      assert {:ok, config} = Ethers.config(rpc_client: ConfigRPC)

      assert config == %{current: @hoodi_cancun, next: @hoodi_prague, last: @hoodi_prague}
    end

    test "decodes null next and last configurations to nil" do
      opts = [rpc_client: ConfigRPC, rpc_opts: [response: {:ok, Fixtures.no_future_fork()}]]

      assert {:ok, %{current: @hoodi_cancun, next: nil, last: nil}} == Ethers.config(opts)
    end

    test "decodes members omitted by the node to nil" do
      # activationTime is left out for forks without a scheduled activation time and
      # systemContracts for forks before Cancun
      partial_next = Map.drop(Fixtures.hoodi_prague(), ["activationTime", "systemContracts"])
      response = %{Fixtures.future_fork_scheduled() | "next" => partial_next}

      assert {:ok, %{next: next, last: @hoodi_prague}} =
               Ethers.config(rpc_client: ConfigRPC, rpc_opts: [response: {:ok, response}])

      assert next == %{@hoodi_prague | activation_time: nil, system_contracts: nil}
    end

    test "ignores members unknown to the spec" do
      current =
        Fixtures.hoodi_cancun()
        |> Map.put("someFutureMember", %{"value" => "0x1"})
        |> Map.update!("blobSchedule", &Map.put(&1, "someFutureBlobParam", 7))

      response =
        Fixtures.no_future_fork()
        |> Map.put("current", current)
        |> Map.put("someFutureConfig", %{"activationTime" => 1})

      assert {:ok, %{current: @hoodi_cancun, next: nil, last: nil}} ==
               Ethers.config(rpc_client: ConfigRPC, rpc_opts: [response: {:ok, response}])
    end

    test "returns RPC errors as is" do
      error = %{"code" => -32_601, "message" => "the method eth_config does not exist"}

      assert {:error, ^error} =
               Ethers.config(rpc_client: ConfigRPC, rpc_opts: [response: {:error, error}])
    end

    test "returns error when the RPC client does not support eth_config" do
      assert {:error, :not_supported} = Ethers.config(rpc_client: Ethers.TestRPCModule)
    end

    test "passes rpc_opts to the RPC client" do
      {:ok, _config} =
        Ethers.config(rpc_client: ConfigRPC, rpc_opts: [send_params_to_pid: self()])

      assert_received :eth_config
    end

    test "works with the default RPC client" do
      assert {:ok, %{current: current, next: next, last: last}} = Ethers.config()

      assert current.chain_id == Ethers.chain_id!()
      assert is_integer(current.activation_time)
      assert current.fork_id =~ ~r/\A0x[0-9a-f]{8}\z/
      assert %{base_fee_update_fraction: _, max: max, target: target} = current.blob_schedule
      assert is_integer(max) and is_integer(target)

      assert current.precompiles["ECREC"] == "0x0000000000000000000000000000000000000001"

      assert current.system_contracts["BEACON_ROOTS_ADDRESS"] ==
               "0x000F3df6D732807Ef1319fB7B8bB8522d0Beac02"

      assert is_nil(next) or is_map(next)
      assert is_nil(last) or is_map(last)
    end
  end

  describe "config!/1" do
    test "returns the unwrapped config" do
      assert %{current: @hoodi_cancun, next: @hoodi_prague, last: @hoodi_prague} ==
               Ethers.config!(rpc_client: ConfigRPC)
    end

    test "raises on error" do
      assert_raise Ethers.ExecutionError, fn ->
        Ethers.config!(rpc_client: Ethers.TestRPCModule)
      end
    end
  end

  describe "batch/2" do
    test "decodes :config results" do
      opts = [rpc_client: ConfigRPC, rpc_opts: [send_params_to_pid: self()]]

      assert {:ok, [{:ok, config}, {:ok, @hoodi_chain_id}]} =
               Ethers.batch([:config, :chain_id], opts)

      assert config == %{current: @hoodi_cancun, next: nil, last: nil}
      assert_received {:batch_request, [{:eth_config, []}, {:eth_chain_id, []}]}
    end

    test "works with the default RPC client" do
      assert {:ok, [{:ok, %{current: %{chain_id: chain_id}}}, {:ok, chain_id}]} =
               Ethers.batch([:config, :chain_id])

      assert is_integer(chain_id)
    end
  end
end
