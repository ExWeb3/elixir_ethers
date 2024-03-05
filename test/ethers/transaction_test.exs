defmodule Ethers.TransactionTest do
  use ExUnit.Case

  alias Ethers.Transaction

  @transaction_fixture %Ethers.Transaction{
    type: :eip1559,
    chain_id: "0x539",
    nonce: "0x516",
    gas: "0x5d30",
    from: "0x90f8bf6a479f320ead074411a4b0e7944ea8c9c1",
    to: "0x95ced938f7991cd0dfcb48f0a06a40fa1af46ebc",
    value: "0x0",
    data:
      "0x435ffe940000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000001268656c6c6f206c6f63616c207369676e65720000000000000000000000000000",
    gas_price: "0x8",
    max_fee_per_gas: "0x8f0d1800",
    max_priority_fee_per_gas: "0x0",
    access_list: [],
    signature_r: "0x639e5b615f34498f3e5a03f4831e4b7a2a1d5b61ed1388181ef7689c01466fc3",
    signature_s: "0x34a9311fae88125c4f9df5d0ed61f8e37bbaf62681f3ce96d03899114df8997",
    signature_y_parity_or_v: "0x1",
    block_hash: "0xa2b720a9653afd26411e9bc94283cc496cd3d763378a67fd645bf1a4e332f37d",
    block_number: "0x595",
    hash: "0xdc78c7e7ea3a5980f732e466daf1fdc4f009e973530d7e84f0b2012f1ff2cfc7",
    transaction_index: "0x0"
  }

  describe "decode_values/1" do
    test "decodes the transaction values to correct types" do
      decoded = Transaction.decode_values(@transaction_fixture)

      assert %{
               type: :eip1559,
               value: 0,
               to: "0x95ced938f7991cd0dfcb48f0a06a40fa1af46ebc",
               hash: "0xdc78c7e7ea3a5980f732e466daf1fdc4f009e973530d7e84f0b2012f1ff2cfc7",
               from: "0x90f8bf6a479f320ead074411a4b0e7944ea8c9c1",
               gas: 23_856,
               block_number: 1429,
               gas_price: 8,
               max_fee_per_gas: 2_400_000_000,
               chain_id: 1337,
               nonce: 1302,
               block_hash: "0xa2b720a9653afd26411e9bc94283cc496cd3d763378a67fd645bf1a4e332f37d",
               transaction_index: 0,
               max_priority_fee_per_gas: 0,
               access_list: [],
               signature_y_parity_or_v: 1,
               signature_r: Ethers.Utils.hex_decode!(@transaction_fixture.signature_r),
               signature_s: Ethers.Utils.hex_decode!(@transaction_fixture.signature_s),
               data: Ethers.Utils.hex_decode!(@transaction_fixture.data)
             } == decoded
    end

    test "does not fail with missing values" do
      assert %{signature_y_parity_or_v: nil} =
               Transaction.decode_values(%{@transaction_fixture | signature_y_parity_or_v: nil})

      assert %{signature_y_parity_or_v: nil} =
               Transaction.decode_values(%{@transaction_fixture | signature_y_parity_or_v: ""})
    end
  end

  describe "encode/1" do
    test "encodes transaction with address having leading zeros" do
      transaction = %Ethers.Transaction{
        type: :eip1559,
        chain_id: "0x00539",
        from: "0x90F8bf6A479f320ead074411a4B0e7944Ea8c9C1",
        to: "0x00008FDEE72ac11b5c542428B35EEF5769C409f0",
        nonce: "0x1",
        gas: "0x1234",
        value: "0x0",
        data: "0x0006fdde03",
        gas_price: "0x10e7467522",
        max_fee_per_gas: "0x1448BAF2F5",
        max_priority_fee_per_gas: "0x0"
      }

      assert "0x02eb8205390180851448baf2f58212349400008fdee72ac11b5c542428b35eef5769c409f080850006fdde03c0" ==
               Transaction.encode(transaction) |> Ethers.Utils.hex_encode()
    end
  end
end
