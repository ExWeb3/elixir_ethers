defmodule Ethers.TypedData.Domain do
  @moduledoc """
  The EIP-712 domain separator data (`EIP712Domain`).

  The domain scopes a signature to a particular application, contract and chain so that a
  signature produced for one domain cannot be replayed in another. All five standard fields are
  optional and only the fields that are actually present (non-nil) participate in the domain
  type - this matches the behaviour of ethers.js / MetaMask and is required for interoperability.

  Standard fields (in canonical EIP-712 order) and their Solidity types:

  | Field                | JSON name           | Solidity type |
  | -------------------- | ------------------- | ------------- |
  | `:name`              | `"name"`            | `string`      |
  | `:version`           | `"version"`         | `string`      |
  | `:chain_id`          | `"chainId"`         | `uint256`     |
  | `:verifying_contract`| `"verifyingContract"`| `address`    |
  | `:salt`              | `"salt"`            | `bytes32`     |

  ## Example

      Ethers.TypedData.Domain.new(
        name: "Ether Mail",
        version: "1",
        chain_id: 1,
        verifying_contract: "0xCcCCccccCCCCcCCCCCCcCcCccCcCCCcCcccccccC"
      )
  """

  alias Ethers.TypedData.Field

  defstruct [:name, :version, :chain_id, :verifying_contract, :salt]

  @typedoc """
  An EIP-712 domain. Every field is optional (`nil` when absent).

  - `name` - human readable name of the signing domain (`string`).
  - `version` - current version of the signing domain (`string`).
  - `chain_id` - the EIP-155 chain id (`uint256`).
  - `verifying_contract` - address of the contract that will verify the signature (`address`).
  - `salt` - a disambiguating 32-byte salt (`bytes32`).
  """
  @type t :: %__MODULE__{
          name: String.t() | nil,
          version: String.t() | nil,
          chain_id: non_neg_integer() | nil,
          verifying_contract: Ethers.Types.t_address() | nil,
          salt: binary() | nil
        }

  # {struct field, JSON name, solidity type} in canonical EIP-712 order.
  @ordered_fields [
    {:name, "name", "string"},
    {:version, "version", "string"},
    {:chain_id, "chainId", "uint256"},
    {:verifying_contract, "verifyingContract", "address"},
    {:salt, "salt", "bytes32"}
  ]

  @doc """
  Creates a new `Ethers.TypedData.Domain` from a keyword list or a map.

  Accepts atom keys (`:chain_id`) or string keys (`"chain_id"`). An existing
  `Ethers.TypedData.Domain` struct is returned unchanged. Unknown keys are ignored.

  ## Examples

      iex> Ethers.TypedData.Domain.new(name: "Ether Mail", version: "1", chain_id: 1)
      %Ethers.TypedData.Domain{name: "Ether Mail", version: "1", chain_id: 1}
  """
  @spec new(t() | map() | keyword()) :: t()
  def new(%__MODULE__{} = domain), do: domain

  def new(fields) when is_list(fields), do: fields |> Map.new() |> new()

  def new(fields) when is_map(fields) do
    %__MODULE__{
      name: fetch(fields, :name),
      version: fetch(fields, :version),
      chain_id: fetch(fields, :chain_id),
      verifying_contract: fetch(fields, :verifying_contract),
      salt: fetch(fields, :salt)
    }
  end

  @doc """
  Returns the present (non-nil) domain fields in canonical EIP-712 order as a list of
  `Ethers.TypedData.Field` structs.

  Each returned `Field` uses the JSON field name (e.g. `"chainId"`) and its Solidity type. Only
  fields that are set participate in the `EIP712Domain` type - absent fields are omitted. This
  is consumed by both the JSON serializer and the hashing engine in later stages.

  ## Examples

      iex> Ethers.TypedData.Domain.new(name: "Ether Mail", chain_id: 1)
      ...> |> Ethers.TypedData.Domain.present_fields()
      [
        %Ethers.TypedData.Field{name: "name", type: "string"},
        %Ethers.TypedData.Field{name: "chainId", type: "uint256"}
      ]
  """
  @spec present_fields(t()) :: [Field.t()]
  def present_fields(%__MODULE__{} = domain) do
    for {key, json_name, solidity_type} <- @ordered_fields,
        not is_nil(Map.fetch!(domain, key)) do
      %Field{name: json_name, type: solidity_type}
    end
  end

  @spec fetch(map(), :name | :version | :chain_id | :verifying_contract | :salt) :: term()
  defp fetch(fields, key) do
    case Map.fetch(fields, key) do
      {:ok, value} -> value
      :error -> Map.get(fields, Atom.to_string(key))
    end
  end
end
