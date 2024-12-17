defmodule Ethers.TransactionTest do
  use ExUnit.Case

  alias Ethers.Transaction

  describe "encode/1" do
    test "encodes transaction with address having leading zeros" do
      transaction = %Ethers.Transaction.Eip1559{
        chain_id: 1337,
        gas: 4660,
        input: "0x0006fdde03",
        max_fee_per_gas: 87_119_557_365,
        max_priority_fee_per_gas: 0,
        nonce: 1,
        to: "0x00008FDEE72ac11b5c542428B35EEF5769C409f0",
        value: 0
      }

      assert "0x02eb8205390180851448baf2f58212349400008fdee72ac11b5c542428b35eef5769c409f080850006fdde03c0" ==
               Transaction.encode(transaction) |> Ethers.Utils.hex_encode()
    end

    test "encodes transaction with empty data" do
      transaction = %Ethers.Transaction.Eip1559{
        chain_id: 1337,
        gas: 4660,
        input: "",
        max_fee_per_gas: 87_119_557_365,
        max_priority_fee_per_gas: 0,
        nonce: 1,
        to: "0x00008FDEE72ac11b5c542428B35EEF5769C409f0",
        value: 0
      }

      assert "0x02e68205390180851448baf2f58212349400008fdee72ac11b5c542428b35eef5769c409f08080c0" ==
               Transaction.encode(transaction) |> Ethers.Utils.hex_encode()
    end
  end
end
