defmodule Ethers.Contracts.CcipRead do
  @moduledoc """
  CCIP Read ([EIP-3668](https://eips.ethereum.org/EIPS/eip-3668)) contract
  """

  use Ethers.Contract, abi: :ccip_read
end
