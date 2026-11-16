defmodule Ethers.Contract.Test.ReceiptCounterContract do
  @moduledoc false
  use Ethers.Contract, abi_file: "tmp/counter_abi.json"
end

defmodule Ethers.Contract.Test.ReceiptHelloWorldContract do
  @moduledoc false
  use Ethers.Contract, abi_file: "tmp/hello_world_abi.json"
end

defmodule Ethers.Contract.Test.ReceiptUsdcContract do
  @moduledoc false
  use Ethers.Contract, abi: :erc20, default_address: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"
end

defmodule Ethers.ReceiptTest.Fixtures do
  @moduledoc false
  # Receipts in the form nodes return them (execution-apis `ReceiptInfo` schema)

  @block_hash "0xffeca860ae9ca8f0db4dd0601f9a323d715ab7bf46a326cfc1ffc84c9c07b76c"
  @empty_logs_bloom "0x" <> String.duplicate("0", 512)

  @vitalik "0xd8da6bf26964af9d7eed9e03e53415d37aa96045"
  @receiver "0x70997970c51812dc3a010c7d01b50e0d17dc79c8"
  @usdc "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48"
  @weth "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2"
  @bayc "0xbc4ca0eda7647a8ab7c2061c2e118a18a936f13d"

  @transfer_topic "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"
  @approval_topic "0x8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b925"

  def block_hash, do: @block_hash

  def eip1559_transfer do
    %{
      "blockHash" => @block_hash,
      "blockNumber" => "0x14909ac",
      "contractAddress" => nil,
      "cumulativeGasUsed" => "0x6b0795",
      "effectiveGasPrice" => "0x1b60bae53",
      "from" => @vitalik,
      "gasUsed" => "0x5208",
      "logs" => [],
      "logsBloom" => @empty_logs_bloom,
      "status" => "0x1",
      "to" => @receiver,
      "transactionHash" => "0xcedec15c0525b48d07e8d008771747bdcf880ff179606a27d884542344a4d46b",
      "transactionIndex" => "0x5e",
      "type" => "0x2"
    }
  end

  def contract_creation do
    %{
      "blockHash" => @block_hash,
      "blockNumber" => "0x1",
      "contractAddress" => "0x5fbdb2315678afecb367f032d93f642f64180aa3",
      "cumulativeGasUsed" => "0x108b47",
      "effectiveGasPrice" => "0x3b9aca00",
      "from" => "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266",
      "gasUsed" => "0x108b47",
      "logs" => [],
      "logsBloom" => @empty_logs_bloom,
      "status" => "0x1",
      "to" => nil,
      "transactionHash" => "0xc2f01a029629919baa5c0b7a6a3a7288bcfc5af60a3f95cb4d82afc3647f99df",
      "transactionIndex" => "0x0",
      "type" => "0x2"
    }
  end

  def failed_transaction do
    %{
      "blockHash" => @block_hash,
      "blockNumber" => "0x14909ac",
      "contractAddress" => nil,
      "cumulativeGasUsed" => "0x6b0795",
      "effectiveGasPrice" => "0x1b60bae53",
      "from" => @vitalik,
      "gasUsed" => "0xcb99",
      "logs" => [],
      "logsBloom" => @empty_logs_bloom,
      "status" => "0x0",
      "to" => @usdc,
      "transactionHash" => "0x2d00ed0b403a747d1e293e4da85f095aa074499f11d16c7dd0a075d93c60150e",
      "transactionIndex" => "0xc",
      "type" => "0x2"
    }
  end

  def blob_transaction do
    %{
      "blobGasPrice" => "0x1",
      "blobGasUsed" => "0x20000",
      "blockHash" => @block_hash,
      "blockNumber" => "0x14909ac",
      "contractAddress" => nil,
      "cumulativeGasUsed" => "0x35b6d3",
      "effectiveGasPrice" => "0x3b9aca00",
      "from" => "0x5050f69a9786f081509234f1a7f4684b5e5b76c9",
      "gasUsed" => "0x5208",
      "logs" => [],
      "logsBloom" => @empty_logs_bloom,
      "status" => "0x1",
      "to" => "0xff00000000000000000000000000000000008453",
      "transactionHash" => "0x89c39187fae2bfd1862e8bbed55aa5f4b73e0e615264c815faa565991b0a577c",
      "transactionIndex" => "0x2",
      "type" => "0x3"
    }
  end

  def pre_byzantium do
    %{
      "blockHash" => @block_hash,
      "blockNumber" => "0xb443",
      "contractAddress" => nil,
      "cumulativeGasUsed" => "0x5208",
      "effectiveGasPrice" => "0x2d79883d2000",
      "from" => @vitalik,
      "gasUsed" => "0x5208",
      "logs" => [],
      "logsBloom" => @empty_logs_bloom,
      "root" => "0x49fbd619f601e32aeeefa0b02d9706c669a437a0ada61baf9c21ac5c8d320517",
      "to" => @receiver,
      "transactionHash" => "0x1f33f7057724f269ae65284509615ad86fa1994af92d2abce0b82c82a2b7b46b",
      "transactionIndex" => "0x0",
      "type" => "0x0"
    }
  end

  # Receipt of an OP Stack chain, with the chain specific L1 fee members
  def op_stack_transaction do
    Map.merge(eip1559_transfer(), %{
      "l1BaseFeeScalar" => "0x8dd",
      "l1BlobBaseFee" => "0x1",
      "l1BlobBaseFeeScalar" => "0x101c12",
      "l1Fee" => "0x1c5ee8a2b4",
      "l1GasPrice" => "0x2540be400",
      "l1GasUsed" => "0x640"
    })
  end

  # OP Stack deposit transaction (type 0x7e), unknown to the library
  def op_stack_deposit do
    Map.merge(eip1559_transfer(), %{
      "depositNonce" => "0x9a2b1",
      "depositReceiptVersion" => "0x1",
      "effectiveGasPrice" => "0x0",
      "type" => "0x7e"
    })
  end

  def token_transfers do
    tx_hash = "0x8a15ef80cd16fdde1c4d8283d81c02902486fd3ae01f48a9da6da88995809d1a"

    logs =
      [
        # ERC-20 Approval(owner, spender, 1 USDC)
        {@usdc, [@approval_topic, address_topic(@vitalik), address_topic(@receiver)],
         word(1_000_000)},
        # ERC-20 Transfer(from, to, 1 USDC)
        {@usdc, [@transfer_topic, address_topic(@vitalik), address_topic(@receiver)],
         word(1_000_000)},
        # ERC-721 Transfer(from, to, tokenId): same signature, the token id is indexed
        {@bayc, [@transfer_topic, address_topic(@vitalik), address_topic(@receiver), word(7382)],
         "0x"},
        # An event unknown to the ERC-20 and ERC-721 ABIs
        {@weth, ["0xe1fffcc4923d04b559f4d29a8bfc6cda04eb5b0d3c460751c2402c5c5cc9109c"], word(10)},
        # ERC-20 Transfer of another token
        {@weth, [@transfer_topic, address_topic(@receiver), address_topic(@vitalik)],
         word(2_000)},
        # ERC-20 Transfer signature and topics but data that does not decode as a uint256
        {@weth, [@transfer_topic, address_topic(@receiver), address_topic(@vitalik)], "0x01"}
      ]
      |> Enum.with_index()
      |> Enum.map(fn {{address, topics, data}, index} ->
        %{
          "address" => address,
          "blockHash" => @block_hash,
          "blockNumber" => "0x14909ac",
          "data" => data,
          "logIndex" => Ethers.Utils.integer_to_hex(16 + index),
          "removed" => false,
          "topics" => topics,
          "transactionHash" => tx_hash,
          "transactionIndex" => "0x5e"
        }
      end)

    Map.merge(eip1559_transfer(), %{
      "gasUsed" => "0x15586",
      "logs" => logs,
      "logsBloom" => "0x" <> String.duplicate("00200000", 64),
      "to" => @usdc,
      "transactionHash" => tx_hash
    })
  end

  defp address_topic("0x" <> address), do: "0x" <> String.duplicate("0", 24) <> address

  defp word(integer) do
    hex = Integer.to_string(integer, 16) |> String.downcase()
    "0x" <> String.pad_leading(hex, 64, "0")
  end
end

defmodule Ethers.ReceiptTest.ReceiptRPC do
  @moduledoc false
  # Returns the response given in the `:response` rpc option

  def eth_get_transaction_receipt(tx_hash, opts) do
    if pid = opts[:send_params_to_pid] do
      send(pid, {:eth_get_transaction_receipt, tx_hash})
    end

    Keyword.fetch!(opts, :response)
  end

  def batch_request(requests, opts) do
    if pid = opts[:send_params_to_pid] do
      send(pid, {:batch_request, requests})
    end

    {:ok,
     Enum.map(requests, fn {:eth_get_transaction_receipt, [_tx_hash]} ->
       Keyword.fetch!(opts, :response)
     end)}
  end
end

defmodule Ethers.ReceiptTest do
  use ExUnit.Case

  import Ethers.TestHelpers

  alias Ethers.Contract.Test.ReceiptCounterContract
  alias Ethers.Contract.Test.ReceiptHelloWorldContract
  alias Ethers.Contract.Test.ReceiptUsdcContract
  alias Ethers.Contract.Test.RevertContract
  alias Ethers.Contracts.ERC20
  alias Ethers.Contracts.ERC721
  alias Ethers.Event
  alias Ethers.EventFilter
  alias Ethers.ExecutionError
  alias Ethers.Receipt
  alias Ethers.ReceiptTest.Fixtures
  alias Ethers.ReceiptTest.ReceiptRPC
  alias Ethers.Utils

  @from "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
  # Not a funded test account: other tests assert the exact balance of those
  @value_receiver "0x9965507D1a55bcC2695C58ba16FB37d819B0A4da"
  @from_private_key "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"

  @vitalik "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045"
  @receiver "0x70997970C51812dc3A010C7d01b50e0d17dc79C8"
  @usdc "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"
  @missing_tx_hash "0x5194596d703a53f65dcb1d7df60fcfa1f7d904ad3145887677a6ab68a425d8d3"

  @known_members ~w(transactionHash transactionIndex blockHash blockNumber from to
                    contractAddress type status root gasUsed cumulativeGasUsed
                    effectiveGasPrice blobGasUsed blobGasPrice logs logsBloom)

  defp get_receipt(response) do
    Ethers.get_transaction_receipt(@missing_tx_hash,
      rpc_client: ReceiptRPC,
      rpc_opts: [response: response]
    )
  end

  defp receipt!(rpc_receipt) do
    {:ok, receipt} = get_receipt({:ok, rpc_receipt})
    receipt
  end

  describe "get_transaction_receipt/2 decoding" do
    test "decodes a successful EIP-1559 transfer" do
      rpc_receipt = Fixtures.eip1559_transfer()

      assert {:ok, receipt} = get_receipt({:ok, rpc_receipt})

      assert receipt == %Receipt{
               transaction_hash:
                 "0xcedec15c0525b48d07e8d008771747bdcf880ff179606a27d884542344a4d46b",
               transaction_index: 94,
               block_hash: Fixtures.block_hash(),
               block_number: 21_563_820,
               from: @vitalik,
               to: @receiver,
               contract_address: nil,
               type: 2,
               status: :success,
               root: nil,
               gas_used: 21_000,
               cumulative_gas_used: 7_014_293,
               effective_gas_price: 7_349_186_131,
               blob_gas_used: nil,
               blob_gas_price: nil,
               logs: [],
               logs_bloom: :binary.copy(<<0>>, 256),
               extra: %{}
             }
    end

    test "decodes a contract creation" do
      assert %Receipt{
               to: nil,
               contract_address: "0x5FbDB2315678afecb367f032d93F642f64180aa3",
               from: "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
               status: :success,
               gas_used: 1_084_231
             } = receipt!(Fixtures.contract_creation())
    end

    test "decodes a failed transaction" do
      assert %Receipt{status: :failure, gas_used: 52_121, to: @usdc, root: nil} =
               receipt!(Fixtures.failed_transaction())
    end

    test "decodes a blob transaction" do
      assert %Receipt{
               type: 3,
               blob_gas_used: 131_072,
               blob_gas_price: 1,
               effective_gas_price: 1_000_000_000,
               to: "0xFf00000000000000000000000000000000008453",
               from: "0x5050F69a9786F081509234F1a7F4684b5E5b76C9"
             } = receipt!(Fixtures.blob_transaction())
    end

    test "decodes a pre-Byzantium receipt with root instead of status" do
      assert %Receipt{
               status: nil,
               root: "0x49fbd619f601e32aeeefa0b02d9706c669a437a0ada61baf9c21ac5c8d320517",
               type: 0,
               block_number: 46_147
             } = receipt!(Fixtures.pre_byzantium())
    end

    test "keeps the members it does not decode undecoded in extra" do
      receipt = receipt!(Fixtures.op_stack_transaction())

      assert receipt.extra == %{
               "l1BaseFeeScalar" => "0x8dd",
               "l1BlobBaseFee" => "0x1",
               "l1BlobBaseFeeScalar" => "0x101c12",
               "l1Fee" => "0x1c5ee8a2b4",
               "l1GasPrice" => "0x2540be400",
               "l1GasUsed" => "0x640"
             }

      for member <- ["gasUsed", "status", "logs"] do
        refute Map.has_key?(receipt.extra, member)
      end

      assert %{receipt | extra: %{}} == receipt!(Fixtures.eip1559_transfer())
    end

    test "has empty extra when the node sends no members it does not decode" do
      for rpc_receipt <- [
            Fixtures.eip1559_transfer(),
            Fixtures.contract_creation(),
            Fixtures.failed_transaction(),
            Fixtures.blob_transaction(),
            Fixtures.pre_byzantium(),
            Fixtures.token_transfers()
          ] do
        assert receipt!(rpc_receipt).extra == %{}
      end
    end

    test "decodes transaction types unknown to the library to their type id" do
      assert %Receipt{type: 126, effective_gas_price: 0, extra: extra} =
               receipt!(Fixtures.op_stack_deposit())

      assert extra == %{"depositNonce" => "0x9a2b1", "depositReceiptVersion" => "0x1"}
    end

    test "keeps logs as returned by the node" do
      rpc_receipt = Fixtures.token_transfers()

      assert %Receipt{logs: logs, logs_bloom: logs_bloom} = receipt!(rpc_receipt)
      assert logs == rpc_receipt["logs"]
      assert logs_bloom == :binary.copy(<<0, 32, 0, 0>>, 64)
    end

    test "decodes members omitted by the node to nil" do
      rpc_receipt = Map.take(Fixtures.eip1559_transfer(), ["transactionHash"])

      assert receipt!(rpc_receipt) == %Receipt{
               transaction_hash: rpc_receipt["transactionHash"],
               extra: %{}
             }
    end

    test "returns an error for members not matching the schema" do
      for {member, value} <- [
            {"status", "0x2"},
            {"status", "0x"},
            {"status", true},
            {"gasUsed", "5208"},
            {"gasUsed", 21_000},
            {"gasUsed", "0xzz"},
            {"gasUsed", "0x-1"},
            {"blockNumber", "0x"},
            {"type", "2"},
            {"from", "0x1234"},
            {"to", "0x" <> String.duplicate("z", 40)},
            {"contractAddress", String.duplicate("a", 40)},
            {"transactionHash", "0x1234"},
            {"blockHash", "0x" <> String.duplicate("z", 64)},
            {"root", 1},
            {"logsBloom", "0xzz"},
            {"logs", %{}},
            {"logs", ["0x1234"]}
          ] do
        rpc_receipt = Map.put(Fixtures.eip1559_transfer(), member, value)

        assert {:error, {:invalid_receipt_member, ^member}} = get_receipt({:ok, rpc_receipt}),
               "expected #{inspect(value)} to be rejected for #{member}"
      end
    end

    test "returns an error for a receipt that is not an object" do
      assert {:error, :invalid_receipt} = get_receipt({:ok, "0x1234"})
    end

    test "returns not found for a null receipt" do
      assert {:error, :transaction_receipt_not_found} = get_receipt({:ok, nil})
    end

    test "returns RPC errors as is" do
      error = %{"code" => -32_000, "message" => "boom"}

      assert {:error, ^error} = get_receipt({:error, error})
    end

    test "bang version raises on malformed receipts" do
      rpc_receipt = Map.put(Fixtures.eip1559_transfer(), "status", "0x2")

      assert_raise ExecutionError, ~r/invalid_receipt_member/, fn ->
        Ethers.get_transaction_receipt!(@missing_tx_hash,
          rpc_client: ReceiptRPC,
          rpc_opts: [response: {:ok, rpc_receipt}]
        )
      end
    end

    test "batch decodes :get_transaction_receipt results" do
      rpc_receipt = Fixtures.eip1559_transfer()

      opts = [
        rpc_client: ReceiptRPC,
        rpc_opts: [response: {:ok, rpc_receipt}, send_params_to_pid: self()]
      ]

      assert {:ok, [{:ok, receipt}]} =
               Ethers.batch([{:get_transaction_receipt, @missing_tx_hash}], opts)

      assert receipt == receipt!(rpc_receipt)

      assert_received {:batch_request, [{:eth_get_transaction_receipt, [@missing_tx_hash]}]}

      opts = [rpc_client: ReceiptRPC, rpc_opts: [response: {:ok, nil}]]

      assert {:ok, [{:error, :transaction_receipt_not_found}]} =
               Ethers.batch([{:get_transaction_receipt, @missing_tx_hash}], opts)
    end
  end

  describe "decode_logs/2" do
    setup do
      [receipt: receipt!(Fixtures.token_transfers())]
    end

    test "decodes all events of an EventFilters module", %{receipt: receipt} do
      assert [
               %Event{
                 address: @usdc,
                 topics: ["Approval(address,address,uint256)", @vitalik, @receiver],
                 data: [1_000_000],
                 log_index: 16
               },
               %Event{
                 address: @usdc,
                 topics: ["Transfer(address,address,uint256)", @vitalik, @receiver],
                 data: [1_000_000],
                 log_index: 17,
                 block_hash: block_hash,
                 block_number: 21_563_820,
                 transaction_hash: transaction_hash,
                 transaction_index: 94,
                 removed: false
               },
               %Event{
                 address: "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2",
                 topics: ["Transfer(address,address,uint256)", @receiver, @vitalik],
                 data: [2_000],
                 log_index: 20
               }
             ] = Receipt.decode_logs(receipt, ERC20.EventFilters)

      assert block_hash == receipt.block_hash
      assert transaction_hash == receipt.transaction_hash
    end

    test "skips events with the same signature but other indexed arguments", %{receipt: receipt} do
      assert [
               %Event{
                 address: "0xBC4CA0EdA7647A8aB7C2061c2E118A18a936f13D",
                 topics: ["Transfer(address,address,uint256)", @vitalik, @receiver, 7382],
                 data: [],
                 log_index: 18
               }
             ] = Receipt.decode_logs(receipt, ERC721.EventFilters)
    end

    test "decodes logs matching a single event filter", %{receipt: receipt} do
      assert [%Event{log_index: 17}, %Event{log_index: 20}] =
               Receipt.decode_logs(receipt, ERC20.EventFilters.transfer(nil, nil))

      assert [%Event{log_index: 17}] =
               Receipt.decode_logs(receipt, ERC20.EventFilters.transfer(@vitalik, nil))

      assert [%Event{log_index: 20}] =
               Receipt.decode_logs(receipt, ERC20.EventFilters.transfer(nil, @vitalik))

      assert [] = Receipt.decode_logs(receipt, ERC20.EventFilters.transfer(@usdc, nil))
    end

    test "skips logs with the signature of an event but malformed data", %{receipt: receipt} do
      # Logs 20 and 21 have the same topics, the data of log 21 is not a uint256
      assert [%Event{log_index: 20}] =
               Receipt.decode_logs(receipt, ERC20.EventFilters.transfer(@receiver, @vitalik))

      [approval_log | _] = receipt.logs
      receipt = %{receipt | logs: [%{approval_log | "data" => "0xzz"}]}

      assert [] = Receipt.decode_logs(receipt, ERC20.EventFilters)
    end

    test "decodes logs matching a combined event filter", %{receipt: receipt} do
      filter =
        EventFilter.combine([
          ERC20.EventFilters.transfer(nil, nil),
          ERC20.EventFilters.approval(nil, nil)
        ])

      assert [%Event{log_index: 16}, %Event{log_index: 17}, %Event{log_index: 20}] =
               Receipt.decode_logs(receipt, filter)
    end

    test "only decodes logs of the default address of the filter", %{receipt: receipt} do
      assert [%Event{log_index: 16}, %Event{log_index: 17}] =
               Receipt.decode_logs(receipt, ReceiptUsdcContract.EventFilters)

      assert [%Event{log_index: 17}] =
               Receipt.decode_logs(receipt, ReceiptUsdcContract.EventFilters.transfer(nil, nil))

      filter = %{ERC20.EventFilters.transfer(nil, nil) | default_address: String.downcase(@usdc)}
      assert [%Event{log_index: 17}] = Receipt.decode_logs(receipt, filter)

      filter = %{ERC20.EventFilters.transfer(nil, nil) | default_address: @vitalik}
      assert [] = Receipt.decode_logs(receipt, filter)
    end

    test "returns an empty list without logs" do
      assert [] = Receipt.decode_logs(receipt!(Fixtures.eip1559_transfer()), ERC20.EventFilters)
      assert [] = Receipt.decode_logs(%Receipt{}, ERC20.EventFilters)
    end

    test "raises for a module which is not an EventFilters module", %{receipt: receipt} do
      assert_raise ArgumentError, ~r/is not an EventFilters module/, fn ->
        Receipt.decode_logs(receipt, ERC20)
      end
    end
  end

  describe "get_transaction_receipt/2 with a node" do
    test "returns the receipt of a transfer" do
      tx_hash =
        Ethers.send_transaction!(%{value: 1000},
          from: @from,
          to: @value_receiver,
          signer: Ethers.Signer.Local,
          signer_opts: [private_key: @from_private_key]
        )

      wait_for_transaction!(tx_hash)

      to = Utils.to_checksum_address(@value_receiver)

      assert {:ok, receipt} = Ethers.get_transaction_receipt(tx_hash)

      assert %Receipt{
               transaction_hash: ^tx_hash,
               from: @from,
               to: ^to,
               contract_address: nil,
               type: 2,
               status: :success,
               gas_used: 21_000,
               logs: []
             } = receipt

      # Node extras differ between anvil versions: only check that known members are decoded
      assert is_map(receipt.extra)
      assert Map.take(receipt.extra, @known_members) == %{}

      assert receipt.cumulative_gas_used >= receipt.gas_used
      assert receipt.effective_gas_price > 0
      assert byte_size(receipt.logs_bloom) == 256

      %Ethers.Transaction.Signed{metadata: metadata} = Ethers.get_transaction!(tx_hash)
      assert metadata.block_hash == receipt.block_hash
      assert metadata.block_number == receipt.block_number
      assert metadata.transaction_index == receipt.transaction_index
    end

    test "returns the contract address of a deployment" do
      {:ok, tx_hash} = Ethers.deploy(ReceiptHelloWorldContract, from: @from)
      wait_for_transaction!(tx_hash)

      assert {:ok, address} = Ethers.deployed_address(tx_hash)

      assert %Receipt{to: nil, status: :success, contract_address: contract_address, extra: extra} =
               Ethers.get_transaction_receipt!(tx_hash)

      assert contract_address == address
      assert Map.take(extra, @known_members) == %{}

      assert ReceiptHelloWorldContract.say_hello() |> Ethers.call!(to: contract_address) ==
               "Hello World!"
    end

    test "returns failure status for a reverted transaction" do
      address = deploy(RevertContract, from: @from)

      tx_hash =
        RevertContract.reverting()
        |> Ethers.send_transaction!(from: @from, to: address, gas: 100_000)

      wait_for_transaction!(tx_hash)

      assert %Receipt{status: :failure, to: ^address} = Ethers.get_transaction_receipt!(tx_hash)
    end

    test "decode_logs/2 decodes the events emitted by a contract call" do
      address =
        deploy(ReceiptCounterContract,
          encoded_constructor: ReceiptCounterContract.constructor(100),
          from: @from
        )

      tx_hash =
        ReceiptCounterContract.set(101)
        |> Ethers.send_transaction!(from: @from, to: address)

      wait_for_transaction!(tx_hash)

      receipt = Ethers.get_transaction_receipt!(tx_hash)
      block_number = receipt.block_number

      assert [
               %Event{
                 address: ^address,
                 topics: ["SetCalled(uint256,uint256)", 100],
                 data: [101],
                 transaction_hash: ^tx_hash,
                 block_number: ^block_number
               }
             ] = events = Receipt.decode_logs(receipt, ReceiptCounterContract.EventFilters)

      assert events ==
               Ethers.get_logs!(ReceiptCounterContract.EventFilters.set_called(nil),
                 address: address,
                 from_block: block_number,
                 to_block: block_number
               )

      assert ^events =
               Receipt.decode_logs(receipt, ReceiptCounterContract.EventFilters.set_called(100))

      assert [] =
               Receipt.decode_logs(receipt, ReceiptCounterContract.EventFilters.set_called(105))

      assert [] = Receipt.decode_logs(receipt, ReceiptHelloWorldContract.EventFilters)

      lowercase_default_address = %{
        ReceiptCounterContract.EventFilters.set_called(nil)
        | default_address: String.downcase(address)
      }

      assert ^events = Receipt.decode_logs(receipt, lowercase_default_address)

      other_default_address = %{
        ReceiptCounterContract.EventFilters.set_called(nil)
        | default_address: @value_receiver
      }

      assert [] = Receipt.decode_logs(receipt, other_default_address)
    end

    test "batch returns receipts" do
      tx_hash =
        Ethers.send_transaction!(%{value: 1000},
          from: @from,
          to: @value_receiver,
          signer: Ethers.Signer.Local,
          signer_opts: [private_key: @from_private_key]
        )

      wait_for_transaction!(tx_hash)

      assert {:ok,
              [
                {:ok, %Receipt{transaction_hash: ^tx_hash, status: :success}},
                {:error, :transaction_receipt_not_found}
              ]} =
               Ethers.batch([
                 {:get_transaction_receipt, tx_hash},
                 {:get_transaction_receipt, @missing_tx_hash}
               ])
    end

    test "returns not found for an unknown transaction" do
      assert {:error, :transaction_receipt_not_found} =
               Ethers.get_transaction_receipt(@missing_tx_hash)
    end
  end
end
