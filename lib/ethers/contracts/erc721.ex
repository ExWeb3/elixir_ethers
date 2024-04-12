defmodule Ethers.Contracts.ERC721 do
  @moduledoc """
  ERC721 token interface

  More info: https://eips.ethereum.org/EIPS/eip-721
  """

  use Ethers.Contract, abi: :erc721

  @behaviour Ethers.Contracts.ERC165

  # ERC-165 Interface ID
  @interface_id Ethers.Utils.hex_decode!("0x80ac58cd")

  @impl Ethers.Contracts.ERC165
  def erc165_interface_id, do: @interface_id
end
