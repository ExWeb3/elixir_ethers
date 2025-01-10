defmodule Ethers.Contract.Test.HelloWorldContract do
  @moduledoc false
  use Ethers.Contract, abi_file: "tmp/hello_world_abi.json"
end

defmodule Ethers.Contract.Test.HelloWorldWithDefaultAddressContract do
  @moduledoc false
  use Ethers.Contract,
    abi_file: "tmp/hello_world_abi.json",
    default_address: "0x1000bf6a479f320ead074411a4b0e7944ea8c9c1"
end

defmodule EthersTest do
  use ExUnit.Case
  doctest Ethers

  import Ethers.TestHelpers

  alias Ethers.Contract.Test.HelloWorldContract
  alias Ethers.Contract.Test.HelloWorldWithDefaultAddressContract
  alias Ethers.ExecutionError

  @from "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266"
  @to "0x9965507d1a55bcc2695c58ba16fb37d819b0a4dc"

  @from_private_key "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"

  describe "current_gas_price" do
    test "returns the correct gas price" do
      assert {:ok, gas_price} = Ethers.current_gas_price()
      assert is_integer(gas_price)
    end
  end

  describe "max_priority_fee_per_gas" do
    test "returns the correct max priority fee per gas" do
      assert {:ok, max_priority_fee_per_gas} = Ethers.max_priority_fee_per_gas()
      assert is_integer(max_priority_fee_per_gas)
    end

    test "bang version returns unwrapped value" do
      assert is_integer(Ethers.max_priority_fee_per_gas!())
    end
  end

  describe "blob_base_fee" do
    test "returns the correct blob base fee" do
      assert {:ok, blob_base_fee} = Ethers.blob_base_fee()
      assert is_integer(blob_base_fee)
    end

    test "bang version returns unwrapped value" do
      assert is_integer(Ethers.blob_base_fee!())
    end
  end

  describe "current_block_number" do
    test "returns the current block number" do
      assert {:ok, n} = Ethers.current_block_number()
      assert n >= 0
    end

    test "can override the rpc options" do
      assert {:ok, 1001} ==
               Ethers.current_block_number(
                 rpc_client: Ethers.TestRPCModule,
                 rpc_opts: [block: "0x3E9"]
               )
    end
  end

  describe "get_balance" do
    test "returns correct balance for account" do
      assert {:ok, 0} == Ethers.get_balance("0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045")

      assert {:ok, 10_000_000_000_000_000_000_000} ==
               Ethers.get_balance("0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc")
    end

    test "bang version returns unwrapped value" do
      assert 10_000_000_000_000_000_000_000 ==
               Ethers.get_balance!("0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc")
    end

    test "bang version raises on error" do
      assert_raise ExecutionError, fn ->
        Ethers.get_balance!("invalid account")
      end
    end

    test "works with binary accounts" do
      bin = Ethers.Utils.hex_decode!("0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc")

      assert {:ok, 10_000_000_000_000_000_000_000} == Ethers.get_balance(bin)
    end

    test "returns error with invalid account" do
      assert {:error, :invalid_account} == Ethers.get_balance("invalid account")
    end
  end

  describe "get_transaction_count" do
    @address "0x23618e81E3f5cdF7f54C3d65f7FBc0aBf5B21E8f"
    test "returns the correct transaction count" do
      assert {:ok, c} = Ethers.get_transaction_count(@address)

      assert is_integer(c)
      assert c >= 0

      Ethers.send_transaction!(%{
        from: @address,
        to: "0xaadA6BF26964aF9D7eEd9e03E53415D37aA96045",
        value: 1000
      })
      |> wait_for_transaction!()

      assert {:ok, c + 1} == Ethers.get_transaction_count(@address)
    end
  end

  describe "get_transaction" do
    test "returns correct transaction by tx_hash" do
      {:ok, tx_hash} =
        HelloWorldContract.set_hello("hello local signer")
        |> Ethers.send_transaction(
          from: @from,
          to: @to,
          signer: Ethers.Signer.Local,
          signer_opts: [
            private_key: @from_private_key
          ]
        )

      wait_for_transaction!(tx_hash)

      checksum_to_addr = Ethers.Utils.to_checksum_address(@to)

      assert {:ok,
              %Ethers.Transaction.Signed{
                payload: %Ethers.Transaction.Eip1559{
                  to: ^checksum_to_addr
                },
                metadata: %Ethers.Transaction.Metadata{
                  block_hash: "0x" <> _,
                  block_number: block_number,
                  transaction_index: 0
                }
              }} = Ethers.get_transaction(tx_hash)

      assert is_integer(block_number) and block_number >= 0
    end

    test "bang version returns unwrapped value" do
      {:ok, tx_hash} =
        HelloWorldContract.set_hello("hello local signer")
        |> Ethers.send_transaction(
          from: @from,
          to: @to,
          signer: Ethers.Signer.Local,
          signer_opts: [
            private_key: @from_private_key
          ]
        )

      wait_for_transaction!(tx_hash)

      assert %Ethers.Transaction.Signed{
               payload: %Ethers.Transaction.Eip1559{
                 to: checksum_to_addr
               }
             } = Ethers.get_transaction!(tx_hash)

      assert checksum_to_addr == Ethers.Utils.to_checksum_address(@to)
    end

    test "bang version raises on error" do
      assert_raise ExecutionError, fn ->
        Ethers.get_transaction!("invalid tx_hash")
      end
    end

    test "works in batch requests" do
      {:ok, tx_hash} =
        HelloWorldContract.set_hello("hello local signer")
        |> Ethers.send_transaction(
          from: @from,
          to: @to,
          signer: Ethers.Signer.Local,
          signer_opts: [
            private_key: @from_private_key
          ]
        )

      wait_for_transaction!(tx_hash)

      assert {:ok,
              [
                ok: %Ethers.Transaction.Signed{
                  payload: %Ethers.Transaction.Eip1559{}
                }
              ]} =
               Ethers.batch([
                 {:get_transaction, tx_hash}
               ])
    end

    test "returns error by non-existent tx_hash" do
      assert {:error, :transaction_not_found} =
               Ethers.get_transaction(
                 "0x5194596d703a53f65dcb1d7df60fcfa1f7d904ad3145887677a6ab68a425d8d3"
               )
    end

    test "returns error by invalid tx_hash" do
      assert {:error, _err} = Ethers.get_transaction("invalid tx_hash")
    end
  end

  describe "get_transaction_receipt" do
    test "returns correct transaction receipt by tx_hash" do
      {:ok, tx_hash} =
        HelloWorldContract.set_hello("hello local signer")
        |> Ethers.send_transaction(
          from: @from,
          to: @to,
          signer: Ethers.Signer.Local,
          signer_opts: [
            private_key: @from_private_key
          ]
        )

      wait_for_transaction!(tx_hash)

      downcased_to_addr = String.downcase(@to)

      assert {:ok,
              %{
                "transactionHash" => ^tx_hash,
                "from" => @from,
                "to" => ^downcased_to_addr
              }} = Ethers.get_transaction_receipt(tx_hash)
    end

    test "bang version returns unwrapped value" do
      {:ok, tx_hash} =
        HelloWorldContract.set_hello("hello local signer")
        |> Ethers.send_transaction(
          from: @from,
          to: @to,
          signer: Ethers.Signer.Local,
          signer_opts: [
            private_key: @from_private_key
          ]
        )

      wait_for_transaction!(tx_hash)

      receipt = Ethers.get_transaction_receipt!(tx_hash)
      assert receipt["transactionHash"] == tx_hash
      assert receipt["from"] == @from
      assert receipt["to"] == String.downcase(@to)
    end

    test "bang version raises on error" do
      assert_raise ExecutionError, fn ->
        Ethers.get_transaction_receipt!("invalid tx_hash")
      end
    end

    test "returns error by non-existent tx_hash" do
      assert {:error, :transaction_receipt_not_found} =
               Ethers.get_transaction_receipt(
                 "0x5194596d703a53f65dcb1d7df60fcfa1f7d904ad3145887677a6ab68a425d8d3"
               )
    end

    test "returns error by invalid tx_hash" do
      assert {:error, _err} = Ethers.get_transaction_receipt("invalid tx_hash")
    end
  end

  describe "contract deployment" do
    test "can deploy a contract given a module which has the binary" do
      contract_address = deploy(HelloWorldContract, from: @from)

      assert HelloWorldContract.say_hello() |> Ethers.call!(to: contract_address) ==
               "Hello World!"
    end

    test "can deploy a contract given the contract binary" do
      bin = HelloWorldContract.__contract_binary__()
      contract_address = deploy(bin, from: @from)

      assert HelloWorldContract.say_hello() |> Ethers.call!(to: contract_address) ==
               "Hello World!"
    end

    test "can deploy a contract given the contract binary prefixed with 0x" do
      bin = HelloWorldContract.__contract_binary__()
      contract_address = deploy("0x" <> bin, from: @from)

      assert HelloWorldContract.say_hello() |> Ethers.call!(to: contract_address) ==
               "Hello World!"
    end

    test "returns error if the module does not include the binary" do
      assert_raise UndefinedFunctionError, fn ->
        assert {:error, :binary_not_found} = Ethers.deploy(NotFoundContract, from: @from)
      end

      assert {:error, :binary_not_found} =
               Ethers.deploy(Ethers.Contracts.ERC20, from: @from)
    end

    test "getting the deployed address of a non existing (not yet validated) transaction" do
      tx_hash = "0x5c504ed432cb51138bcf09aa5e8a410dd4a1e204ef84bfed1be16dfba1b22060"
      assert {:error, :transaction_not_found} = Ethers.deployed_address(tx_hash)
    end

    test "getting the deployed address of a non contract creation transaction" do
      contract_address = deploy(HelloWorldContract, from: @from)

      {:ok, tx_hash} =
        HelloWorldContract.set_hello("Bye")
        |> Ethers.send_transaction(to: contract_address, from: @from)

      wait_for_transaction!(tx_hash)

      assert {:error, :no_contract_address} = Ethers.deployed_address(tx_hash)

      assert HelloWorldContract.say_hello() |> Ethers.call!(to: contract_address) ==
               "Bye"
    end
  end

  describe "get_logs/2" do
    test "returns error when request fails" do
      assert {:error, %{reason: :nxdomain}} =
               Ethers.get_logs(%{topics: [], selector: nil},
                 rpc_opts: [url: "http://non.exists"]
               )
    end

    test "with bang function, raises error when request fails" do
      assert_raise Mint.TransportError, "non-existing domain", fn ->
        Ethers.get_logs!(%{topics: [], selector: nil},
          rpc_opts: [url: "http://non.exists"]
        )
      end
    end
  end

  describe "default address" do
    test "is included in the function calls when has default address" do
      assert %Ethers.TxData{
               base_module: HelloWorldWithDefaultAddressContract,
               data: "0xef5fb05b",
               selector: %ABI.FunctionSelector{
                 function: "sayHello",
                 method_id: <<239, 95, 176, 91>>,
                 type: :function,
                 inputs_indexed: nil,
                 state_mutability: :view,
                 input_names: [],
                 types: [],
                 returns: [:string],
                 return_names: [""]
               },
               default_address: "0x1000bf6a479f320ead074411a4b0e7944ea8c9c1"
             } == HelloWorldWithDefaultAddressContract.say_hello()

      assert %{data: "0xef5fb05b", to: "0x1000bf6a479f320ead074411a4b0e7944ea8c9c1"} ==
               HelloWorldWithDefaultAddressContract.say_hello()
               |> Ethers.TxData.to_map([])
    end

    test "is not included in the function calls when does not have default address" do
      assert %Ethers.TxData{
               base_module: HelloWorldContract,
               data: "0xef5fb05b",
               selector: %ABI.FunctionSelector{
                 function: "sayHello",
                 method_id: <<239, 95, 176, 91>>,
                 type: :function,
                 inputs_indexed: nil,
                 state_mutability: :view,
                 input_names: [],
                 types: [],
                 returns: [:string],
                 return_names: [""]
               },
               default_address: nil
             } == HelloWorldContract.say_hello()
    end

    test "is included in event filters when has default address" do
      assert %Ethers.EventFilter{
               topics: [
                 "0xbe6cf5e99b344c66895d6304d442b2f51b6359ee51ac581db2255de9373e24b8"
               ],
               selector: %ABI.FunctionSelector{
                 function: "HelloSet",
                 method_id:
                   Ethers.Utils.hex_decode!(
                     "0xbe6cf5e99b344c66895d6304d442b2f51b6359ee51ac581db2255de9373e24b8"
                   ),
                 type: :event,
                 inputs_indexed: [false],
                 state_mutability: nil,
                 input_names: ["message"],
                 types: [:string],
                 returns: []
               },
               default_address: "0x1000bf6a479f320ead074411a4b0e7944ea8c9c1"
             } == HelloWorldWithDefaultAddressContract.EventFilters.hello_set()

      assert %{
               topics: ["0xbe6cf5e99b344c66895d6304d442b2f51b6359ee51ac581db2255de9373e24b8"],
               address: "0x1000bf6a479f320ead074411a4b0e7944ea8c9c1"
             } ==
               HelloWorldWithDefaultAddressContract.EventFilters.hello_set()
               |> Ethers.EventFilter.to_map([])
    end

    test "is not included in event filters when does not have default address" do
      assert %Ethers.EventFilter{
               topics: [
                 "0xbe6cf5e99b344c66895d6304d442b2f51b6359ee51ac581db2255de9373e24b8"
               ],
               selector: %ABI.FunctionSelector{
                 function: "HelloSet",
                 method_id:
                   Ethers.Utils.hex_decode!(
                     "0xbe6cf5e99b344c66895d6304d442b2f51b6359ee51ac581db2255de9373e24b8"
                   ),
                 type: :event,
                 inputs_indexed: [false],
                 state_mutability: nil,
                 input_names: ["message"],
                 types: [:string],
                 returns: []
               },
               default_address: nil
             } == HelloWorldContract.EventFilters.hello_set()
    end
  end

  describe "batch/2" do
    test "Can batch multiple requests" do
      address = deploy(HelloWorldContract, from: @from)

      HelloWorldContract.set_hello("Hello Batch!")
      |> Ethers.send_transaction!(to: address, from: @from)
      |> wait_for_transaction!()

      assert {:ok, results} =
               Ethers.batch([
                 {:call, HelloWorldContract.say_hello(), to: address},
                 {:send, HelloWorldContract.set_hello("hi"), from: @from, to: address},
                 :net_version,
                 {:estimate_gas, HelloWorldContract.say_hello(), to: address},
                 {:get_logs, HelloWorldContract.EventFilters.hello_set(), address: address},
                 :current_block_number,
                 :current_gas_price,
                 {:eth_call, [%{}, "latest"]}
               ])

      assert [
               ok: "Hello Batch!",
               ok: "0x" <> _hash,
               ok: <<_net_version::binary>>,
               ok: gas_estimate,
               ok: [%Ethers.Event{}],
               ok: block_number,
               ok: gas_price,
               ok: "0x"
             ] = results

      assert is_integer(gas_estimate)
      assert is_integer(block_number)
      assert is_integer(gas_price)
    end

    test "returns error for invalid action" do
      assert {:error, :no_to_address} = Ethers.batch([{:call, HelloWorldContract.say_hello()}])
    end
  end

  describe "batch!/2" do
    test "returns the correct result" do
      address = deploy(HelloWorldContract, from: @from)

      assert [ok: "Hello World!", ok: _] =
               Ethers.batch!([
                 {:call, HelloWorldContract.say_hello(), to: address},
                 :current_block_number
               ])

      assert_raise ExecutionError, "Unexpected error: no_to_address", fn ->
        Ethers.batch!([{:call, HelloWorldContract.say_hello()}])
      end
    end
  end

  describe "deploy/2" do
    test "accepts signer and signer_opts" do
      assert {:error, :no_private_key} =
               Ethers.deploy(HelloWorldContract, from: @from, signer: Ethers.Signer.Local)
    end
  end

  describe "send_transaction/2" do
    test "accepts signer and signer_opts" do
      assert {:error, :no_private_key} =
               HelloWorldContract.set_hello("hello")
               |> Ethers.send_transaction(
                 from: @from,
                 to: "0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc",
                 signer: Ethers.Signer.Local
               )
    end

    test "signs and sends an eip1559 transaction using a signer" do
      address = deploy(HelloWorldContract, from: @from)

      assert {:ok, tx_hash} =
               HelloWorldContract.set_hello("hello local signer")
               |> Ethers.send_transaction(
                 from: @from,
                 to: address,
                 signer: Ethers.Signer.Local,
                 signer_opts: [
                   private_key: @from_private_key
                 ]
               )

      wait_for_transaction!(tx_hash)

      assert {:ok, "hello local signer"} =
               Ethers.call(HelloWorldContract.say_hello(), to: address)
    end

    test "signs and sends a legacy transaction using a signer" do
      address = deploy(HelloWorldContract, from: @from)

      {:ok, tx_hash} =
        HelloWorldContract.set_hello("hello local signer")
        |> Ethers.send_transaction(
          from: @from,
          to: address,
          type: Ethers.Transaction.Legacy,
          signer: Ethers.Signer.Local,
          signer_opts: [
            private_key: @from_private_key
          ]
        )

      wait_for_transaction!(tx_hash)

      assert {:ok, %Ethers.Transaction.Signed{payload: %Ethers.Transaction.Legacy{}}} =
               Ethers.get_transaction(tx_hash)

      assert {:ok, "hello local signer"} =
               Ethers.call(HelloWorldContract.say_hello(), to: address)
    end

    test "converts all integer params and overrides to hex" do
      assert {:ok, _tx_hash} =
               Ethers.send_transaction(
                 %{value: 1000},
                 rpc_client: Ethers.TestRPCModule,
                 from: @from,
                 to: "0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc",
                 rpc_opts: [send_params_to_pid: self()]
               )

      assert_receive %{
        from: @from,
        to: "0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc",
        value: "0x3E8",
        type: "0x2"
      }
    end

    test "works with all transaction types" do
      types = [
        Ethers.Transaction.Legacy,
        Ethers.Transaction.Eip1559,
        Ethers.Transaction.Eip2930,
        Ethers.Transaction.Eip4844
      ]

      for type <- types do
        assert {:ok, tx_hash} =
                 Ethers.send_transaction(
                   %{value: 1000},
                   rpc_client: Ethers.TestRPCModule,
                   from: @from,
                   type: type,
                   to: "0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc",
                   rpc_opts: [send_params_to_pid: self()]
                 )

        type_id = Ethers.Utils.integer_to_hex(type.type_id())

        assert_receive %{
          from: @from,
          to: "0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc",
          value: "0x3E8",
          type: ^type_id
        }
      end
    end

    test "works with all transaction types and local signer" do
      types = [
        Ethers.Transaction.Legacy,
        Ethers.Transaction.Eip1559,
        Ethers.Transaction.Eip2930
        # Does not work with Anvil without sidecar
        # Ethers.Transaction.Eip4844
      ]

      for type <- types do
        assert {:ok, tx_hash} =
                 Ethers.send_transaction(
                   %{value: 1000},
                   from: @from,
                   type: type,
                   to: "0x9965507D1a55bcC2695C58ba16FB37d819B0A4da",
                   signer: Ethers.Signer.Local,
                   blob_versioned_hashes: [
                     Ethers.Utils.hex_decode!(
                       "0x01bb9dc6ee48ae6a6f7ffd69a75196a4d49723beedf35981106e8da0efd8f796"
                     )
                   ],
                   access_list: access_list_fixture(),
                   signer_opts: [
                     private_key: @from_private_key
                   ]
                 )

        wait_for_transaction!(tx_hash)

        type_id = Ethers.Utils.integer_to_hex(type.type_id())

        assert %Ethers.Transaction.Signed{payload: %^type{}} = Ethers.get_transaction!(tx_hash)
        assert Ethers.get_transaction_receipt!(tx_hash)["type"] == type_id
      end
    end
  end

  describe "sign_transaction/2" do
    test "returns the signed eip1559 transaction and is valid" do
      address = deploy(HelloWorldContract, from: @from)

      assert {:ok, "0x02" <> _ = signed} =
               HelloWorldContract.set_hello("hi signed")
               |> Ethers.sign_transaction(
                 from: @from,
                 to: address,
                 signer: Ethers.Signer.JsonRPC,
                 type: Ethers.Transaction.Eip1559
               )

      assert {:ok, tx_hash} = Ethers.send_transaction(signed)
      wait_for_transaction!(tx_hash)

      assert {:ok, "hi signed"} = Ethers.call(HelloWorldContract.say_hello(), to: address)
    end

    test "returns the signed legacy transaction and is valid" do
      address = deploy(HelloWorldContract, from: @from)

      assert {:ok, signed} =
               HelloWorldContract.set_hello("hi signed")
               |> Ethers.sign_transaction(
                 from: @from,
                 to: address,
                 signer: Ethers.Signer.JsonRPC,
                 type: Ethers.Transaction.Legacy
               )

      refute String.starts_with?(signed, "0x02")

      assert {:ok, tx_hash} = Ethers.rpc_client().eth_send_raw_transaction(signed)
      wait_for_transaction!(tx_hash)

      assert {:ok, "hi signed"} = Ethers.call(HelloWorldContract.say_hello(), to: address)
    end

    test "uses Signer.JsonRPC as default signer" do
      address = deploy(HelloWorldContract, from: @from)

      assert {:ok, signed} =
               HelloWorldContract.set_hello("hi signed")
               |> Ethers.sign_transaction(from: @from, to: address)

      assert {:ok, tx_hash} = Ethers.rpc_client().eth_send_raw_transaction(signed)
      wait_for_transaction!(tx_hash)

      assert {:ok, "hi signed"} = Ethers.call(HelloWorldContract.say_hello(), to: address)
    end

    test "requires from address" do
      assert {:error, :no_from_address} =
               HelloWorldContract.set_hello("hi signed")
               |> Ethers.sign_transaction(
                 to: "0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc",
                 signer: Ethers.Signer.JsonRPC
               )
    end

    test "requires signer" do
      assert {:error, :no_signer} =
               HelloWorldContract.set_hello("hi signed")
               |> Ethers.sign_transaction(
                 from: @from,
                 to: "0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc",
                 signer: nil
               )
    end
  end

  describe "sign_transaction!/2" do
    test "returns signed transaction" do
      signed =
        HelloWorldContract.set_hello("hi signed")
        |> Ethers.sign_transaction!(
          from: @from,
          gas: 10_000,
          max_fee_per_gas: 123_123_123,
          chain_id: 31_337,
          nonce: 100,
          to: "0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc",
          signer: Ethers.Signer.JsonRPC
        )

      assert String.starts_with?(signed, "0x02")
    end

    test "returns signed transaction with custom max_priority_fee_per_gas" do
      signed =
        HelloWorldContract.set_hello("hi signed")
        |> Ethers.sign_transaction!(
          from: @from,
          gas: 10_000,
          max_fee_per_gas: 123_123_123,
          max_priority_fee_per_gas: 2_000_000_000,
          chain_id: 31_337,
          nonce: 100,
          to: "0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc",
          signer: Ethers.Signer.JsonRPC
        )

      assert String.starts_with?(signed, "0x02")
    end

    test "raises in case of error" do
      assert_raise Ethers.ExecutionError, "Unexpected error: no_from_address", fn ->
        HelloWorldContract.set_hello("hi signed")
        |> Ethers.sign_transaction!(
          to: "0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc",
          signer: Ethers.Signer.JsonRPC
        )
      end
    end
  end

  describe "call/2" do
    test "works without selector (raw call)" do
      address = deploy(HelloWorldContract, from: @from)

      tx_data = HelloWorldContract.say_hello()

      assert {:ok,
              "0x000000000000000000000000000000000000000000000000000000000000002000000000000" <>
                "0000000000000000000000000000000000000000000000000000c48656c6c6f20576f726c642100" <>
                "00000000000000000000000000000000000000"} =
               Ethers.call(%{data: tx_data.data}, to: address)
    end
  end

  describe "deprecated send/2 and send!/2 still work" do
    test "send/2 still works" do
      address = deploy(HelloWorldContract, from: @from)

      {:ok, tx_hash} =
        HelloWorldContract.set_hello("hi send")
        |> Ethers.send(to: address, from: @from)

      wait_for_transaction!(tx_hash)

      assert {:ok, "hi send"} = Ethers.call(HelloWorldContract.say_hello(), to: address)
    end

    test "send!/2 still works" do
      address = deploy(HelloWorldContract, from: @from)

      tx_hash =
        HelloWorldContract.set_hello("hi send!")
        |> Ethers.send!(to: address, from: @from)

      wait_for_transaction!(tx_hash)

      assert {:ok, "hi send!"} = Ethers.call(HelloWorldContract.say_hello(), to: address)
    end
  end

  describe "chain_id" do
    test "returns the chain id" do
      assert {:ok, chain_id} = Ethers.chain_id()
      # Anvil's default chain id
      assert chain_id == 31_337
    end

    test "bang version returns unwrapped value" do
      assert Ethers.chain_id!() == 31_337
    end
  end

  defp access_list_fixture do
    [
      [
        <<7, 166, 233, 85, 186, 67, 69, 186, 232, 58, 194, 166, 250, 167, 113, 253, 221, 138, 32,
          17>>,
        [
          <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0>>,
          <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 1>>,
          <<0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 8>>
        ]
      ],
      [
        <<125, 26, 250, 123, 113, 143, 184, 147, 219, 48, 163, 171, 192, 207, 198, 8, 170, 207,
          235, 176>>,
        [
          <<20, 213, 49, 41, 66, 36, 14, 86, 92, 86, 174, 193, 24, 6, 206, 88, 227, 192, 227, 140,
            150, 38, 157, 117, 156, 93, 53, 162, 162, 228, 164, 73>>,
          <<39, 1, 253, 11, 38, 56, 243, 61, 178, 37, 217, 28, 106, 219, 218, 212, 101, 144, 168,
            106, 9, 162, 178, 195, 134, 64, 92, 47, 116, 42, 248, 66>>,
          <<55, 176, 184, 46, 229, 216, 168, 134, 114, 223, 56, 149, 164, 106, 244, 139, 188, 211,
            13, 110, 252, 201, 8, 19, 110, 41, 69, 111, 163, 6, 4, 187>>
        ]
      ],
      [
        <<160, 184, 105, 145, 198, 33, 139, 54, 193, 209, 157, 74, 46, 158, 176, 206, 54, 6, 235,
          72>>,
        [
          <<55, 87, 12, 241, 140, 109, 149, 116, 74, 21, 79, 162, 177, 155, 126, 149, 140, 120,
            239, 104, 184, 198, 10, 128, 220, 82, 127, 193, 94, 44, 235, 143>>,
          <<110, 137, 211, 30, 63, 216, 210, 191, 11, 65, 28, 69, 142, 152, 199, 70, 59, 247, 35,
            135, 140, 60, 232, 168, 69, 188, 249, 220, 59, 46, 57, 23>>
        ]
      ]
    ]
  end
end
