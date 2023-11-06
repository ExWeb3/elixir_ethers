defmodule Ethers.Contracts.Multicall3 do
  @moduledoc """
  Multicall3 token interface

  More info: https://www.multicall3.com
  """

  @multicall3_address "0xcA11bde05977b3631167028862bE2a173976CA11"

  use Ethers.Contract, abi: :multicall3, default_address: @multicall3_address
end
