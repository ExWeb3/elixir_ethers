defmodule Ethers.Contracts.ERC1155 do
  @moduledoc """
  ERC1155 token interface

  More info: https://eips.ethereum.org/EIPS/eip-1155
  """

  use Ethers.Contract, abi: :erc1155

  @behaviour Ethers.Contracts.ERC165

  # ERC-165 Interface ID
  @interface_id Ethers.Utils.hex_decode!("0xd9b67a26")

  @impl Ethers.Contracts.ERC165
  def erc165_interface_id, do: @interface_id
end
