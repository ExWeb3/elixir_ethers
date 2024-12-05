defmodule Ethers.Contracts.ENS do
  @moduledoc """
  Ethereum Name Service (ENS) Contract
  """

  @ens_address "0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e"

  use Ethers.Contract, abi: :ens, default_address: @ens_address

  defmodule Resolver do
    @moduledoc """
    Ethereum Name Service (ENS) Resolver Contract
    """

    use Ethers.Contract, abi: :ens_resolver
  end

  defmodule ExtendedResolver do
    @moduledoc """
    Extended ENS resolver as per [ENSIP-10](https://docs.ens.domains/ensip/10)
    """

    use Ethers.Contract, abi: :ens_extended_resolver

    @behaviour Ethers.Contracts.ERC165

    # ERC-165 Interface ID
    @interface_id Ethers.Utils.hex_decode!("0x9061b923")

    @impl Ethers.Contracts.ERC165
    def erc165_interface_id, do: @interface_id
  end
end
