defmodule Ethers.TransactionUnknownTest.Fixtures do
  @moduledoc false

  # eth_getTransactionByHash response for the OP Mainnet L1 attributes deposit transaction
  # 0x47b7a389d253158f3f2cb367dfd23eba2f95f641a3b671651515a673628d7c50 (block 159588978),
  # verbatim. Field meanings: https://specs.optimism.io/protocol/deposits.html
  def deposit_transaction do
    %{
      "blockHash" => "0x79bc44f1be182bd534510b742f0faa2536a54c1027644d4b437dd736d3b3045f",
      "blockNumber" => "0x9832272",
      "blockTimestamp" => "0x6afa1e9d",
      "depositReceiptVersion" => "0x1",
      "from" => "0xdeaddeaddeaddeaddeaddeaddeaddeaddead0001",
      "gas" => "0xf4240",
      "gasPrice" => "0x0",
      "hash" => "0x47b7a389d253158f3f2cb367dfd23eba2f95f641a3b671651515a673628d7c50",
      "input" =>
        "0x3db6be2b0000146b000f79c50000000000000004000000006afa1e4b0000000001932ec2000000000000000000000000000000000000000000000000000000000ae177c70000000000000000000000000000000000000000000000000000000000970e30bdc4f20ce549b2f6595461719afda17cdc4346bf97556858c6a32e62ef015a5c0000000000000000000000006887246668a3b87f54deb3b94ba47a6f63f329850000000000000000000000000190",
      "mint" => "0x0",
      "nonce" => "0x33d601b",
      "r" => "0x0",
      "s" => "0x0",
      "sourceHash" => "0x817dce692d94a9f2a738f9856f0faf3a942260a5d51684a5ac3823f5f1542f44",
      "to" => "0x4200000000000000000000000000000000000015",
      "transactionIndex" => "0x0",
      "type" => "0x7e",
      "v" => "0x0",
      "value" => "0x0",
      "yParity" => "0x0"
    }
  end

  def deposit_transaction_hash, do: deposit_transaction()["hash"]
end

defmodule Ethers.TransactionUnknownTest.DepositRPC do
  @moduledoc false
  # Answers eth_getTransactionByHash with the OP Mainnet deposit transaction fixture.

  alias Ethers.TransactionUnknownTest.Fixtures

  def eth_get_transaction_by_hash(tx_hash, opts) do
    if pid = opts[:send_params_to_pid] do
      send(pid, {:eth_get_transaction_by_hash, tx_hash})
    end

    {:ok, transaction_by_hash(tx_hash)}
  end

  def batch_request(requests, opts) do
    if pid = opts[:send_params_to_pid] do
      send(pid, {:batch_request, requests})
    end

    {:ok,
     Enum.map(requests, fn {:eth_get_transaction_by_hash, [tx_hash]} ->
       {:ok, transaction_by_hash(tx_hash)}
     end)}
  end

  defp transaction_by_hash(tx_hash) do
    if tx_hash == Fixtures.deposit_transaction_hash(), do: Fixtures.deposit_transaction()
  end
end

defmodule Ethers.TransactionUnknownTest do
  use ExUnit.Case, async: true

  alias Ethers.Transaction
  alias Ethers.Transaction.Metadata
  alias Ethers.Transaction.Unknown
  alias Ethers.TransactionUnknownTest.DepositRPC
  alias Ethers.TransactionUnknownTest.Fixtures
  alias Ethers.Utils

  @deposit_tx_hash "0x47b7a389d253158f3f2cb367dfd23eba2f95f641a3b671651515a673628d7c50"

  describe "from_rpc_map/1 with an unregistered type" do
    test "returns an OP-stack deposit transaction as Unknown" do
      rpc_map = Fixtures.deposit_transaction()

      assert {:ok, %Unknown{} = transaction} = Transaction.from_rpc_map(rpc_map)

      assert transaction == %Unknown{
               type_id: 0x7E,
               hash: @deposit_tx_hash,
               from: "0xDeaDDEaDDeAdDeAdDEAdDEaddeAddEAdDEAd0001",
               to: "0x4200000000000000000000000000000000000015",
               nonce: 54_353_947,
               value: 0,
               gas: 1_000_000,
               input: Utils.hex_decode!(rpc_map["input"]),
               chain_id: nil,
               metadata: %Metadata{
                 block_hash: "0x79bc44f1be182bd534510b742f0faa2536a54c1027644d4b437dd736d3b3045f",
                 block_number: 159_588_978,
                 transaction_index: 0
               },
               raw: rpc_map
             }

      assert transaction.raw["sourceHash"] ==
               "0x817dce692d94a9f2a738f9856f0faf3a942260a5d51684a5ac3823f5f1542f44"
    end

    test "decodes atom keys and keeps the original map" do
      rpc_map =
        Map.new(Fixtures.deposit_transaction(), fn {key, value} ->
          {String.to_atom(key), value}
        end)

      {:ok, %Unknown{} = from_string_keys} =
        Transaction.from_rpc_map(Fixtures.deposit_transaction())

      assert {:ok, %Unknown{} = transaction} = Transaction.from_rpc_map(rpc_map)
      assert transaction.raw == rpc_map
      assert transaction.raw.mint == "0x0"
      assert %Unknown{transaction | raw: nil} == %Unknown{from_string_keys | raw: nil}
    end

    test "leaves missing fields nil" do
      rpc_map = %{"type" => "0x7e", "to" => nil}

      assert {:ok, transaction} = Transaction.from_rpc_map(rpc_map)

      assert transaction == %Unknown{
               type_id: 0x7E,
               metadata: %Metadata{},
               raw: rpc_map
             }
    end

    test "returns from and to EIP-55 checksummed in any input casing" do
      from = "0xDeaDDEaDDeAdDeAdDEAdDEaddeAddEAdDEAd0001"
      to = "0x70997970C51812dc3A010C7d01b50e0d17dc79C8"

      for address_case <- [&String.downcase/1, &String.upcase/1, & &1] do
        rpc_map = %{"type" => "0x7e", "from" => address_case.(from), "to" => address_case.(to)}

        assert {:ok, %Unknown{from: ^from, to: ^to}} = Transaction.from_rpc_map(rpc_map)
      end

      assert {:ok, %Unknown{from: ^from, to: nil}} =
               Transaction.from_rpc_map(%{"type" => "0x7e", "from" => from, "to" => nil})
    end

    test "reads input, or data when input is missing" do
      assert {:ok, %Unknown{input: <<0xAB, 0xCD>>}} =
               Transaction.from_rpc_map(%{"type" => "0x7e", "data" => "0xabcd"})

      assert {:ok, %Unknown{input: ""}} =
               Transaction.from_rpc_map(%{"type" => "0x7e", "input" => "0x", "data" => "0xabcd"})
    end

    test "leaves fields with invalid values nil and keeps them in raw" do
      rpc_map = %{
        "type" => "0x7e",
        "hash" => "0x47b7a389",
        "from" => "0xdeaddeaddeaddeaddeaddeaddeaddeaddead000g",
        "to" => "4200000000000000000000000000000000000015",
        "nonce" => "12",
        "value" => "0xzz",
        "gas" => 21_000,
        "input" => "0xzz12",
        "chainId" => "0x",
        "blockHash" => 1,
        "blockNumber" => "latest",
        "transactionIndex" => "0x-1"
      }

      assert {:ok, transaction} = Transaction.from_rpc_map(rpc_map)

      assert transaction == %Unknown{type_id: 0x7E, metadata: %Metadata{}, raw: rpc_map}
    end

    test "decodes any type id" do
      for {type, type_id} <- [{"0x71", 0x71}, {"0x7E", 0x7E}, {"0xff", 0xFF}, {"0x100", 0x100}] do
        assert {:ok, %Unknown{type_id: ^type_id}} = Transaction.from_rpc_map(%{"type" => type})
      end
    end

    test "returns an error for a type that is not a hex quantity" do
      for type <- ["0xzz", "0x", "7e", 126, :deposit] do
        assert {:error, :invalid_type} = Transaction.from_rpc_map(%{"type" => type})
      end
    end
  end

  describe "from_rpc_map/1 with a registered type" do
    @eip1559_rpc_map %{
      "type" => "0x2",
      "chainId" => "0x1",
      "nonce" => "0x0",
      "to" => "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb5",
      "value" => "0x0",
      "gas" => "0x5208",
      "maxFeePerGas" => "0x3b9aca00",
      "maxPriorityFeePerGas" => "0x0"
    }

    test "decodes it with the type's module" do
      assert {:ok, %Transaction.Eip1559{}} = Transaction.from_rpc_map(@eip1559_rpc_map)

      assert {:ok, %Transaction.Eip1559{}} =
               Transaction.from_rpc_map(%{@eip1559_rpc_map | "type" => "0x02"})

      legacy_rpc_map =
        @eip1559_rpc_map
        |> Map.drop(["type", "maxFeePerGas", "maxPriorityFeePerGas"])
        |> Map.put("gasPrice", "0x3b9aca00")

      assert {:ok, %Transaction.Legacy{}} = Transaction.from_rpc_map(legacy_rpc_map)

      assert {:ok, %Transaction.Legacy{}} =
               Transaction.from_rpc_map(Map.put(legacy_rpc_map, "type", "0x0"))
    end

    test "still returns errors for missing or invalid fields" do
      assert {:error, :missing_chain_id} =
               Transaction.from_rpc_map(Map.delete(@eip1559_rpc_map, "chainId"))

      assert_raise ArgumentError, fn ->
        Transaction.from_rpc_map(%{@eip1559_rpc_map | "nonce" => "0xzz"})
      end
    end
  end

  describe "read-only" do
    setup do
      {:ok, transaction} = Transaction.from_rpc_map(Fixtures.deposit_transaction())
      %{transaction: transaction}
    end

    test "encode/1 raises an ArgumentError", %{transaction: transaction} do
      assert_raise ArgumentError,
                   "Unsupported transaction type 0x7E: Ethers.Transaction.Unknown is read-only " <>
                     "and cannot be encoded",
                   fn -> Transaction.encode(transaction) end
    end

    test "transaction_hash/2 raises an ArgumentError", %{transaction: transaction} do
      message =
        "Unsupported transaction type 0x7E: Ethers.Transaction.Unknown is read-only " <>
          "and cannot be hashed"

      for format <- [:hex, :bin] do
        assert_raise ArgumentError, message, fn ->
          Transaction.transaction_hash(transaction, format)
        end
      end

      assert_raise ArgumentError, message, fn -> Transaction.transaction_hash(transaction) end
    end

    test "to_rpc_map/1 raises an ArgumentError", %{transaction: transaction} do
      assert_raise ArgumentError,
                   "Unsupported transaction type 0x7E: Ethers.Transaction.Unknown is read-only " <>
                     "and cannot be converted to an RPC map",
                   fn -> Transaction.to_rpc_map(transaction) end
    end

    test "the protocol returns the type id and raises for the type envelope", %{
      transaction: transaction
    } do
      assert Transaction.Protocol.type_id(transaction) == 0x7E

      assert_raise ArgumentError, ~r/^Unsupported transaction type 0x7E: /, fn ->
        Transaction.Protocol.type_envelope(transaction)
      end
    end
  end

  test "decode/1 still rejects raw transactions of an unregistered type" do
    assert {:error, :unsupported_transaction_type} = Transaction.decode(<<0x7E, 0xC0>>)
  end

  describe "Ethers.get_transaction/2" do
    test "returns an Unknown for an unregistered type" do
      assert {:ok, %Unknown{type_id: 0x7E, hash: @deposit_tx_hash} = transaction} =
               Ethers.get_transaction(@deposit_tx_hash,
                 rpc_client: DepositRPC,
                 rpc_opts: [send_params_to_pid: self()]
               )

      assert_received {:eth_get_transaction_by_hash, @deposit_tx_hash}
      assert transaction.raw == Fixtures.deposit_transaction()

      assert Ethers.get_transaction!(@deposit_tx_hash, rpc_client: DepositRPC) == transaction
    end

    test "returns an Unknown in batch requests" do
      assert {:ok, [ok: %Unknown{type_id: 0x7E, hash: @deposit_tx_hash}]} =
               Ethers.batch([{:get_transaction, @deposit_tx_hash}],
                 rpc_client: DepositRPC,
                 rpc_opts: [send_params_to_pid: self()]
               )

      assert_received {:batch_request, [{:eth_get_transaction_by_hash, [@deposit_tx_hash]}]}
    end
  end
end
