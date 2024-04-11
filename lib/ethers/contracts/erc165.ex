defmodule Ethers.Contracts.ERC165 do
  @moduledoc """
  ERC-165 Standard Interface Detection

  More info: https://eips.ethereum.org/EIPS/eip-165
  """
  use Ethers.Contract, abi: :erc165

  @behaviour __MODULE__

  @callback erc165_interface_id() :: <<_::32>>

  @interface_id Ethers.Utils.hex_decode!("0x01ffc9a7")

  defmodule NotERC165CompatibleError do
    defexception [:message]
  end

  @impl __MODULE__
  def erc165_interface_id, do: @interface_id

  def supports_interface(iface) when is_atom(iface) do
    supports_interface(iface.erc165_interface_id())
  rescue
    UndefinedFunctionError ->
      reraise NotERC165CompatibleError,
              "module #{iface} does not implement ERC165 behaviour",
              __STACKTRACE__
  end
end
