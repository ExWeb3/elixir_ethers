defmodule Ethers.Contracts.ERC721 do
  @moduledoc """
  ERC721 token interface

  More info: https://ethereum.org/en/developers/docs/standards/tokens/erc-721/
  """

  use Ethers.Contract, abi: :erc721
end
