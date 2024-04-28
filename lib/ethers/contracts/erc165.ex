defmodule Ethers.Contracts.ERC165 do
  @moduledoc """
  ERC-165 Standard Interface Detection

  More info: https://eips.ethereum.org/EIPS/eip-165

  ## Modules as Interface IDs

  Contract modules can opt to implement EIP-165 behaviour so that their name can be used
  directly with the `supports_interface/1` function in this module. See below example:

  ```elixir
  defmodule MyEIP165CompatibleContract do
    use Ethers.Contract, abi: ...
    @behaviour Ethers.Contracts.ERC165

    @impl true
    def erc165_interface_id, do: Ethers.Utils.hex_decode("[interface_id]")
  end
  ```

  Now module name can be used instead of interface_id and will have the same result.

  ```elixir
  iex> Ethers.Contracts.ERC165.supports_interface("[interface_id]") ==
    Ethers.Contracts.ERC165.supports_interface(MyEIP165CompatibleContract)
  true
  ```
  """
  use Ethers.Contract, abi: :erc165, skip_docs: true

  @behaviour __MODULE__

  @callback erc165_interface_id() :: <<_::32>>

  @interface_id Ethers.Utils.hex_decode!("0x01ffc9a7")

  defmodule Errors.NotERC165CompatibleError do
    defexception [:message]
  end

  @impl __MODULE__
  def erc165_interface_id, do: @interface_id

  @doc """
  Prepares `supportsInterface(bytes4 interfaceId)` call parameters on the contract.

  This function also accepts a module that implements the ERC165 behaviour as input. Example:

  ```elixir
  iex> #{Macro.to_string(__MODULE__)}.supports_interface(Ethers.Contracts.ERC721)
  #Ethers.TxData<function supportsInterface(...)>
  ```

  This function should only be called for result and never in a transaction on
  its own. (Use Ethers.call/2)

  State mutability: view

  ## Function Parameter Types

  - interfaceId: `{:bytes, 4}`

  ## Return Types (when called with `Ethers.call/2`)

  - :bool
  """
  @spec supports_interface(<<_::32>> | atom()) :: Ethers.TxData.t()
  def supports_interface(module_or_interface_id)

  def supports_interface(module) when is_atom(module) do
    supports_interface(module.erc165_interface_id())
  rescue
    UndefinedFunctionError ->
      reraise __MODULE__.Errors.NotERC165CompatibleError,
              "module #{module} does not implement ERC165 behaviour",
              __STACKTRACE__
  end
end
