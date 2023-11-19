defmodule Ethers.NameService do
  @moduledoc """
  Name Service resolution implementation
  """

  import Ethers, only: [keccak_module: 0]

  alias Ethers.Contracts.ENS

  @zero_address Ethers.Types.default(:address)

  @doc """
  Resolves a name on blockchain.

  ## Parameters
  - name: Domain name to resolve. (Example: `foo.eth`)
  - opts: Resolve options.
    - to: Resolver contract address. Defaults to ENS
    - Accepts all other Execution options from `Ethers.call/2`.

  ## Examples

  ```elixir
  Ethers.NameService.resolve("vitalik.eth")
  {:ok, "0xd8da6bf26964af9d7eed9e03e53415d37aa96045"}
  ```
  """
  @spec resolve(String.t(), Keyword.t()) ::
          {:ok, Ethers.Types.t_address()} | {:error, :domain_not_found | term()}
  def resolve(name, opts \\ []) do
    name_hash = name_hash(name)

    with {:ok, resolver} <- get_resolver(name_hash, opts) do
      opts = Keyword.put(opts, :to, resolver)
      Ethers.call(ENS.Resolver.addr(name_hash), opts)
    end
  end

  @doc """
  Same as `resolve/2` but raises on errors.

  ## Examples

  ```elixir
  Ethers.NameService.resolve!("vitalik.eth")
  "0xd8da6bf26964af9d7eed9e03e53415d37aa96045"
  ```
  """
  @spec resolve!(String.t(), Keyword.t()) :: Ethers.Types.t_address() | no_return
  def resolve!(name, opts \\ []) do
    case resolve(name, opts) do
      {:ok, addr} -> addr
      {:error, reason} -> raise "Name Resolution failed: #{inspect(reason)}"
    end
  end

  @doc """
  Implementation of namehash function in Elixir.

  See https://docs.ens.domains/contract-api-reference/name-processing

  ## Examples

      iex> Ethers.NameService.name_hash("foo.eth")
      Ethers.Utils.hex_decode!("0xde9b09fd7c5f901e23a3f19fecc54828e9c848539801e86591bd9801b019f84f")

      iex> Ethers.NameService.name_hash("alisina.eth")
      Ethers.Utils.hex_decode!("0x1b557b3901bef3a986febf001c3b19370b34064b130d49ea967bf150f6d23dfe")
  """
  @spec name_hash(String.t()) :: <<_::256>>
  def name_hash(name) do
    name
    |> String.to_charlist()
    |> :idna.encode(transitional: false, std3_rules: true, uts46: true)
    |> to_string()
    |> String.split(".")
    |> do_name_hash()
  end

  defp do_name_hash([label | rest]) do
    keccak_module().hash_256(do_name_hash(rest) <> keccak_module().hash_256(label))
  end

  defp do_name_hash([]), do: <<0::256>>

  defp get_resolver(name_hash, opts) do
    params = ENS.resolver(name_hash)

    case Ethers.call(params, opts) do
      {:ok, @zero_address} -> {:error, :domain_not_found}
      {:ok, resolver} -> {:ok, resolver}
      {:error, reason} -> {:error, reason}
    end
  end
end
