defmodule Elixirium.Contract.ERC20 do
  @moduledoc """
  ERC20 token interface

  More info: https://ethereum.org/en/developers/docs/standards/tokens/erc-20/
  """

  use Elixirium.Contract, abi: :erc20
end
