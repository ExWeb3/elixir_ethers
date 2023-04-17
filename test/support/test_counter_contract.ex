defmodule Ethers.Contract.Test.CounterContract do
  @moduledoc """
  Test contract
  """

  use Ethers.Contract, abi_file: "tmp/counter_abi.json"
end
