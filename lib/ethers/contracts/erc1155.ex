defmodule Ethers.Contracts.ERC1155 do
  @moduledoc """
  ERC1155 token interface

  More info: https://ethereum.org/en/developers/docs/standards/tokens/erc-1155/
  """

  use Ethers.Contract, abi: :erc1155
end
