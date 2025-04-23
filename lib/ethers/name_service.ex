defmodule Ethers.NameService do
  @moduledoc """
  Name Service resolution implementation for ENS (Ethereum Name Service).
  Supports both forward and reverse resolution plus reverse lookups.

  This module implements [Cross Chain / Offchain Resolvers](https://docs.ens.domains/resolvers/ccip-read)
  (is CCIP-Read aware), allowing it to resolve names that are stored:
  - On-chain (traditional L1 ENS resolution on Ethereum)
  - Off-chain (via CCIP-Read gateway servers)
  - Cross-chain (on other L2s and EVM-compatible blockchains)

  The resolution process automatically handles these different scenarios transparently,
  following the ENS standards for name resolution including ENSIP-10 and ENSIP-11.
  """

  import Ethers, only: [keccak_module: 0]

  alias Ethers.CcipRead
  alias Ethers.Contracts.ENS
  alias Ethers.Contracts.ERC165

  @zero_address Ethers.Types.default(:address)

  @doc """
  Resolves a name on blockchain.

  ## Parameters
  - name: Domain name to resolve. (Example: `foo.eth`)
  - opts: Resolve options.
    - resolve_call: TxData for resolution (Defaults to
    `Ethers.Contracts.ENS.Resolver.addr(Ethers.NameService.name_hash(name))`)
    - to: Resolver contract address. Defaults to ENS
    - Accepts all other Execution options from `Ethers.call/2`.

  ## Examples

  ```elixir
  Ethers.NameService.resolve("vitalik.eth")
  {:ok, "0xd8da6bf26964af9d7eed9e03e53415d37aa96045"}
  ```
  """
  @spec resolve(String.t(), Keyword.t()) ::
          {:ok, Ethers.Types.t_address()}
          | {:error, :domain_not_found | :record_not_found | term()}
  def resolve(name, opts \\ []) do
    with {:ok, resolver} <- get_last_resolver(name, opts) do
      do_resolve(resolver, name, opts)
    end
  end

  defp do_resolve(resolver, name, opts) do
    {resolve_call, opts} =
      Keyword.pop_lazy(opts, :resolve_call, fn ->
        name
        |> name_hash()
        |> ENS.Resolver.addr()
      end)

    case supports_extended_resolver(resolver, opts) do
      {:ok, true} ->
        # ENSIP-10 support
        opts = Keyword.put(opts, :to, resolver)

        resolve_call
        |> ensip10_resolve(name, opts)
        |> handle_result()

      {:ok, false} ->
        opts = Keyword.put(opts, :to, resolver)

        resolve_call
        |> Ethers.call(opts)
        |> handle_result()

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp handle_result(result) do
    case result do
      {:ok, @zero_address} -> {:error, :record_not_found}
      {:ok, address} -> {:ok, address}
      {:error, reason} -> {:error, reason}
    end
  end

  defp ensip10_resolve(resolve_call, name, opts) do
    resolve_call_data = resolve_call.data
    dns_encoded_name = dns_encode(name)
    wildcard_call = ENS.ExtendedResolver.resolve(dns_encoded_name, resolve_call_data)

    with {:ok, result} <- CcipRead.call(wildcard_call, opts) do
      Ethers.TxData.abi_decode(result, resolve_call)
    end
  end

  defp supports_extended_resolver(resolver, opts) do
    opts = Keyword.put(opts, :to, resolver)

    call = ERC165.supports_interface(ENS.ExtendedResolver)

    Ethers.call(call, opts)
  end

  @doc """
  Same as `resolve/2` but raises on errors.

  ## Examples

  ```elixir
  Ethers.NameService.resolve!("vitalik.eth")
  "0xd8da6bf26964af9d7eed9e03e53415d37aa96045"
  ```
  """
  @spec resolve!(String.t(), Keyword.t()) :: Ethers.Types.t_address() | no_return()
  def resolve!(name, opts \\ []) do
    case resolve(name, opts) do
      {:ok, addr} -> addr
      {:error, reason} -> raise "Name Resolution failed: #{inspect(reason)}"
    end
  end

  @doc """
  Resolves an address to a name on blockchain.

  ## Parameters
  - address: Address to resolve.
  - opts: Resolve options.
    - to: Resolver contract address. Defaults to ENS.
    - chain_id: Chain ID of the target chain Defaults to `1`.
    - Accepts all other Execution options from `Ethers.call/2`.

  ## Examples

  ```elixir
  Ethers.NameService.reverse_resolve("0xd8da6bf26964af9d7eed9e03e53415d37aa96045")
  {:ok, "vitalik.eth"}
  ```
  """
  @spec reverse_resolve(Ethers.Types.t_address(), Keyword.t()) ::
          {:ok, String.t()}
          | {:error, :domain_not_found | :invalid_name | :forward_resolution_mismatch | term()}
  def reverse_resolve(address, opts \\ []) do
    address = String.downcase(address)
    chain_id = Keyword.get(opts, :chain_id, 1)

    {reverse_name, coin_type} = get_reverse_name(address, chain_id)
    name_hash = name_hash(reverse_name)

    with {:ok, resolver} <- get_resolver(name_hash, opts),
         {:ok, name} <- resolve_name(resolver, name_hash, opts),
         # Return early if no name found and we're not on default
         {:ok, name} <- handle_empty_name(name, coin_type, address, opts),
         # Verify forward resolution matches
         :ok <- verify_forward_resolution(name, address, opts) do
      {:ok, name}
    end
  end

  defp get_reverse_name("0x" <> address, 1), do: {"#{address}.addr.reverse", 60}

  defp get_reverse_name("0x" <> address, chain_id) do
    # ENSIP-11: coinType = 0x80000000 | chainId
    coin_type = Bitwise.bor(0x80000000, chain_id)
    coin_type_hex = Integer.to_string(coin_type, 16)
    {"#{address}.#{coin_type_hex}.reverse", coin_type}
  end

  defp handle_empty_name("", coin_type, address, opts) when coin_type != 0 do
    "0x" <> address = address
    # Try default reverse name
    reverse_name = "#{address}.default.reverse"
    name_hash = name_hash(reverse_name)

    case get_resolver(name_hash, []) do
      {:ok, resolver} -> resolve_name(resolver, name_hash, opts)
      {:error, reason} -> {:error, reason}
    end
  end

  defp handle_empty_name(name, _coin_type, _address_hash, _opts), do: {:ok, name}

  defp verify_forward_resolution(name, address, opts) do
    with {:ok, resolved_addr} <- resolve(name, opts) do
      if String.downcase(resolved_addr) == String.downcase(address) do
        :ok
      else
        {:error, :forward_resolution_mismatch}
      end
    end
  end

  @doc """
  Same as `reverse_resolve/2` but raises on errors.

  ## Examples

  ```elixir
  Ethers.NameService.reverse_resolve!("0xd8da6bf26964af9d7eed9e03e53415d37aa96045")
  "vitalik.eth"
  ```
  """
  @spec reverse_resolve!(Ethers.Types.t_address(), Keyword.t()) :: String.t() | no_return()
  def reverse_resolve!(address, opts \\ []) do
    case reverse_resolve(address, opts) do
      {:ok, name} -> name
      {:error, reason} -> raise "Reverse Name Resolution failed: #{inspect(reason)}"
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
    |> normalize_dns_name()
    |> String.split(".")
    |> do_name_hash()
  end

  defp do_name_hash([label | rest]) do
    keccak_module().hash_256(do_name_hash(rest) <> keccak_module().hash_256(label))
  end

  defp do_name_hash([]), do: <<0::256>>

  defp get_last_resolver(name, opts) do
    # HACK: get all resolvers at once using Multicall
    name
    |> name_hash()
    |> ENS.resolver()
    |> Ethers.call(opts)
    |> case do
      {:ok, @zero_address} ->
        parent = get_name_parent(name)

        if parent != name do
          get_last_resolver(parent, opts)
        else
          :error
        end

      {:ok, resolver} ->
        {:ok, resolver}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp get_resolver(name_hash, opts) do
    params = ENS.resolver(name_hash)

    case Ethers.call(params, opts) do
      {:ok, @zero_address} -> {:error, :domain_not_found}
      {:ok, resolver} -> {:ok, resolver}
      {:error, reason} -> {:error, reason}
    end
  end

  defp resolve_name(resolver, name_hash, opts) do
    opts = Keyword.put(opts, :to, resolver)

    name_hash
    |> ENS.Resolver.name()
    |> Ethers.call(opts)
  end

  defp normalize_dns_name(name) do
    name
    |> String.to_charlist()
    |> :idna.encode(transitional: false, std3_rules: true, uts46: true)
    |> to_string()
  end

  # Encodes a DNS name according to section 3.1 of RFC1035.
  defp dns_encode(name) when is_binary(name) do
    name
    |> normalize_dns_name()
    |> to_fqdn()
    |> String.split(".")
    |> encode_labels()
  end

  defp to_fqdn(dns_name) do
    if String.ends_with?(dns_name, ".") do
      dns_name
    else
      dns_name <> "."
    end
  end

  defp encode_labels(labels) do
    labels
    |> Enum.reduce(<<>>, fn label, acc ->
      label_length = byte_size(label)
      acc <> <<label_length>> <> label
    end)
  end

  defp get_name_parent(name) do
    case String.split(name, ".", parts: 2) do
      [_, parent] -> parent
      [tld] -> tld
    end
  end
end
