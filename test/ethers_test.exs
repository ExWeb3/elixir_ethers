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

      Ethers.send!(%{
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
        |> Ethers.send(
          from: @from,
          to: @to,
          signer: Ethers.Signer.Local,
          signer_opts: [
            private_key: @from_private_key
          ]
        )

      downcased_to_addr = String.downcase(@to)

      assert {:ok,
              %Ethers.Transaction{
                hash: ^tx_hash,
                from: @from,
                to: ^downcased_to_addr
              }} = Ethers.get_transaction(tx_hash)
    end

    test "works in batch requests" do
      {:ok, tx_hash} =
        HelloWorldContract.set_hello("hello local signer")
        |> Ethers.send(
          from: @from,
          to: @to,
          signer: Ethers.Signer.Local,
          signer_opts: [
            private_key: @from_private_key
          ]
        )

      assert {:ok,
              [
                ok: %Ethers.Transaction{hash: ^tx_hash}
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
        |> Ethers.send(
          from: @from,
          to: @to,
          signer: Ethers.Signer.Local,
          signer_opts: [
            private_key: @from_private_key
          ]
        )

      downcased_to_addr = String.downcase(@to)

      Process.sleep(50)

      assert {:ok,
              %{
                "transactionHash" => ^tx_hash,
                "from" => @from,
                "to" => ^downcased_to_addr
              }} = Ethers.get_transaction_receipt(tx_hash)
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
      assert {:error, :binary_not_found} = Ethers.deploy(NotFoundContract, from: @from)

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
        HelloWorldContract.set_hello("Bye") |> Ethers.send(to: contract_address, from: @from)

      Process.sleep(50)

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
      |> Ethers.send!(to: address, from: @from)
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

  describe "send/2" do
    test "accepts signer and signer_opts" do
      assert {:error, :no_private_key} =
               HelloWorldContract.set_hello("hello")
               |> Ethers.send(
                 from: @from,
                 to: "0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc",
                 signer: Ethers.Signer.Local
               )
    end

    test "signs and sends an eip1559 transaction using a signer" do
      address = deploy(HelloWorldContract, from: @from)

      assert {:ok, tx_hash} =
               HelloWorldContract.set_hello("hello local signer")
               |> Ethers.send(
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

      assert {:ok, _tx_hash} =
               HelloWorldContract.set_hello("hello local signer")
               |> Ethers.send(
                 from: @from,
                 to: address,
                 tx_type: :legacy,
                 signer: Ethers.Signer.Local,
                 signer_opts: [
                   private_key: @from_private_key
                 ]
               )

      Process.sleep(50)

      assert {:ok, "hello local signer"} =
               Ethers.call(HelloWorldContract.say_hello(), to: address)
    end

    test "converts all integer params and overrides to hex" do
      assert {:ok, _tx_hash} =
               Ethers.send(
                 %{value: 1000},
                 rpc_client: Ethers.TestRPCModule,
                 from: @from,
                 to: "0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc",
                 rpc_opts: [send_params_to_pid: self()]
               )

      assert_receive %{
        from: @from,
        gas: "0x119",
        to: "0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc",
        value: "0x3E8"
      }
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
                 tx_type: :eip1559
               )

      assert {:ok, tx_hash} = Ethers.send(signed)
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
                 tx_type: :legacy
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
          chain_id: 1337,
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
          chain_id: 1337,
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
end
