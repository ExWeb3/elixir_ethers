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
end
