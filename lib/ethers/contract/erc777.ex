defmodule Ethers.Contract.ERC777 do
  @moduledoc """
  ERC777 token interface

  More info: https://ethereum.org/en/developers/docs/standards/tokens/erc-777/
  """

  use Ethers.Contract, abi: :erc777
end
