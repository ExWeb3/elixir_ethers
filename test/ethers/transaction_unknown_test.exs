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
      "input" => deposit_input(),
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

  # The same transaction encoded as the spec defines it: 0x7e || rlp([sourceHash, from, to, mint,
  # value, gas, isSystemTx, data]). Its keccak hash is the transaction hash above.
  def raw_deposit_transaction do
    "0x7ef90106a0817dce692d94a9f2a738f9856f0faf3a942260a5d51684a5ac3823f5f1542f4494deaddeaddeaddeaddeaddeaddeaddeaddead00019442000000000000000000000000000000000000158080830f424080b8b2" <>
      String.trim_leading(deposit_input(), "0x")
  end

  def deposit_input do
    "0x3db6be2b0000146b000f79c50000000000000004000000006afa1e4b0000000001932ec2000000000000000000000000000000000000000000000000000000000ae177c70000000000000000000000000000000000000000000000000000000000970e30bdc4f20ce549b2f6595461719afda17cdc4346bf97556858c6a32e62ef015a5c0000000000000000000000006887246668a3b87f54deb3b94ba47a6f63f329850000000000000000000000000190"
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

  alias Ethers.Signer
  alias Ethers.Transaction
  alias Ethers.Transaction.Metadata
  alias Ethers.Transaction.Unknown
  alias Ethers.TransactionUnknownTest.DepositRPC
  alias Ethers.TransactionUnknownTest.Fixtures
  alias Ethers.Utils

  @deposit_tx_hash "0x47b7a389d253158f3f2cb367dfd23eba2f95f641a3b671651515a673628d7c50"
  @private_key "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"

  describe "from_rpc_map/1 with an unregistered type" do
    test "returns an OP-stack deposit transaction as Unknown" do
      rpc_map = Fixtures.deposit_transaction()

      assert {:ok, transaction} = Transaction.from_rpc_map(rpc_map)

      assert transaction == %Unknown{
               type_id: 0x7E,
               rpc_map: rpc_map,
               raw_payload: nil,
               metadata: %Metadata{
                 block_hash: "0x79bc44f1be182bd534510b742f0faa2536a54c1027644d4b437dd736d3b3045f",
                 block_number: 159_588_978,
                 transaction_index: 0
               }
             }

      assert transaction.rpc_map["hash"] == @deposit_tx_hash
    end

    test "keeps a map with atom keys" do
      rpc_map =
        Map.new(Fixtures.deposit_transaction(), fn {key, value} ->
          {String.to_atom(key), value}
        end)

      {:ok, %Unknown{} = from_string_keys} =
        Transaction.from_rpc_map(Fixtures.deposit_transaction())

      assert {:ok, %Unknown{} = transaction} = Transaction.from_rpc_map(rpc_map)
      assert transaction.rpc_map == rpc_map
      assert transaction.metadata == from_string_keys.metadata
    end

    test "leaves missing or invalid metadata nil" do
      for rpc_map <- [
            %{"type" => "0x7e"},
            %{
              "type" => "0x7e",
              "blockHash" => "0x79bc44f1",
              "blockNumber" => "latest",
              "transactionIndex" => "0x-1"
            }
          ] do
        assert {:ok, transaction} = Transaction.from_rpc_map(rpc_map)
        assert transaction == %Unknown{type_id: 0x7E, rpc_map: rpc_map, metadata: %Metadata{}}
      end
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

  describe "decode/1 with an unregistered type" do
    test "returns an OP-stack deposit transaction as Unknown" do
      <<0x7E, raw_payload::binary>> = raw = Utils.hex_decode!(Fixtures.raw_deposit_transaction())

      assert {:ok, transaction} = Transaction.decode(raw)
      assert transaction == %Unknown{type_id: 0x7E, raw_payload: raw_payload}
      assert {:ok, ^transaction} = Transaction.decode(Fixtures.raw_deposit_transaction())

      rpc_map = Fixtures.deposit_transaction()

      assert ExRLP.decode(raw_payload) == [
               Utils.hex_decode!(rpc_map["sourceHash"]),
               Utils.hex_decode!(rpc_map["from"]),
               Utils.hex_decode!(rpc_map["to"]),
               "",
               "",
               <<1_000_000::24>>,
               "",
               Utils.hex_decode!(rpc_map["input"])
             ]
    end

    test "encodes back to the same bytes and hashes them" do
      raw = Utils.hex_decode!(Fixtures.raw_deposit_transaction())
      {:ok, transaction} = Transaction.decode(raw)

      assert Transaction.encode(transaction) == raw
      assert Transaction.transaction_hash(transaction) == @deposit_tx_hash

      assert Transaction.transaction_hash(transaction, :bin) ==
               Utils.hex_decode!(@deposit_tx_hash)
    end

    test "does not validate the payload" do
      for raw <- [<<0x7E>>, <<0x71, 0xFF>>, <<0x7F, 0xC0, 0x00>>] do
        <<type_id, raw_payload::binary>> = raw

        assert {:ok, %Unknown{type_id: ^type_id, raw_payload: ^raw_payload} = transaction} =
                 Transaction.decode(raw)

        assert Transaction.encode(transaction) == raw
      end
    end
  end

  describe "unsupported operations" do
    setup do
      {:ok, from_rpc_map} = Transaction.from_rpc_map(Fixtures.deposit_transaction())
      {:ok, decoded} = Transaction.decode(Fixtures.raw_deposit_transaction())
      %{from_rpc_map: from_rpc_map, decoded: decoded}
    end

    test "encode/1 raises without raw_payload", %{from_rpc_map: transaction} do
      assert_raise ArgumentError,
                   "Unsupported transaction type 0x7E: Ethers.Transaction.Unknown without " <>
                     "raw_payload cannot be encoded",
                   fn -> Transaction.encode(transaction) end
    end

    test "transaction_hash/2 raises without raw_payload", %{from_rpc_map: transaction} do
      message =
        "Unsupported transaction type 0x7E: Ethers.Transaction.Unknown without raw_payload " <>
          ~s(cannot be hashed, the hash reported by the node is in rpc_map["hash"])

      for format <- [:hex, :bin] do
        assert_raise ArgumentError, message, fn ->
          Transaction.transaction_hash(transaction, format)
        end
      end

      assert_raise ArgumentError, message, fn -> Transaction.transaction_hash(transaction) end
    end

    test "to_rpc_map/1 raises", %{from_rpc_map: from_rpc_map, decoded: decoded} do
      for transaction <- [from_rpc_map, decoded] do
        assert_raise ArgumentError,
                     "Unsupported transaction type 0x7E: Ethers.Transaction.Unknown cannot be " <>
                       "converted to an RPC map",
                     fn -> Transaction.to_rpc_map(transaction) end
      end
    end

    test "signing raises", %{from_rpc_map: from_rpc_map, decoded: decoded} do
      assert_raise ArgumentError,
                   "Unsupported transaction type 0x7E: Ethers.Transaction.Unknown cannot be " <>
                     "signed or converted to an RLP list",
                   fn ->
                     Signer.Local.sign_transaction(decoded, private_key: @private_key)
                   end

      assert_raise ArgumentError, ~r/^Unsupported transaction type 0x7E: /, fn ->
        Signer.Local.sign_transaction(from_rpc_map, private_key: @private_key)
      end

      for transaction <- [from_rpc_map, decoded] do
        assert_raise ArgumentError, ~r/cannot be converted to an RPC map$/, fn ->
          Signer.JsonRPC.sign_transaction(transaction, [])
        end
      end
    end

    test "the protocol returns the type id and envelope", %{decoded: transaction} do
      assert Transaction.Protocol.type_id(transaction) == 0x7E
      assert Transaction.Protocol.type_envelope(transaction) == <<0x7E>>

      assert_raise ArgumentError,
                   "Unsupported transaction type 0x100: not an EIP-2718 transaction type",
                   fn -> Transaction.Protocol.type_envelope(%Unknown{type_id: 0x100}) end
    end
  end

  describe "Ethers.get_transaction/2" do
    test "returns an Unknown for an unregistered type" do
      assert {:ok, %Unknown{type_id: 0x7E} = transaction} =
               Ethers.get_transaction(@deposit_tx_hash,
                 rpc_client: DepositRPC,
                 rpc_opts: [send_params_to_pid: self()]
               )

      assert_received {:eth_get_transaction_by_hash, @deposit_tx_hash}
      assert transaction.rpc_map == Fixtures.deposit_transaction()

      assert Ethers.get_transaction!(@deposit_tx_hash, rpc_client: DepositRPC) == transaction
    end

    test "returns an Unknown in batch requests" do
      assert {:ok, [ok: %Unknown{type_id: 0x7E, rpc_map: rpc_map}]} =
               Ethers.batch([{:get_transaction, @deposit_tx_hash}],
                 rpc_client: DepositRPC,
                 rpc_opts: [send_params_to_pid: self()]
               )

      assert rpc_map == Fixtures.deposit_transaction()
      assert_received {:batch_request, [{:eth_get_transaction_by_hash, [@deposit_tx_hash]}]}
    end
  end
end
