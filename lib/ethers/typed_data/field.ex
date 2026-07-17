defmodule Ethers.TypedData.Field do
  @moduledoc """
  A single member of an EIP-712 struct type.

  A field pairs a member `name` with its Solidity `type` string (e.g. `"string"`,
  `"address"`, `"uint256"`, `"Person"`, `"Person[]"`). The ordered list of fields for a
  given struct type is what `encodeType`/`hashStruct` operate on in the EIP-712 algorithm.

  Both `name` and `type` are plain strings using the JSON/Solidity spelling (for example the
  domain's chain id field is named `"chainId"` with type `"uint256"`).
  """

  @enforce_keys [:name, :type]
  defstruct [:name, :type]

  @typedoc """
  An EIP-712 struct member.

  - `name` - the member name as it appears in the message (e.g. `"wallet"`, `"chainId"`).
  - `type` - the Solidity type string of the member (e.g. `"address"`, `"Person[]"`).
  """
  @type t :: %__MODULE__{
          name: String.t(),
          type: String.t()
        }

  @doc """
  Creates a new `Ethers.TypedData.Field` from a map, keyword list, or an existing field.

  Accepts atom (`:name`/`:type`) or string (`"name"`/`"type"`) keys. An existing
  `Ethers.TypedData.Field` is returned unchanged.

  ## Examples

      iex> Ethers.TypedData.Field.new(%{name: "wallet", type: "address"})
      %Ethers.TypedData.Field{name: "wallet", type: "address"}

      iex> Ethers.TypedData.Field.new(%{"name" => "contents", "type" => "string"})
      %Ethers.TypedData.Field{name: "contents", type: "string"}
  """
  @spec new(t() | map() | keyword()) :: t()
  def new(%__MODULE__{} = field), do: field

  def new(field) when is_list(field), do: field |> Map.new() |> new()

  def new(%{name: name, type: type}),
    do: %__MODULE__{name: to_string(name), type: to_string(type)}

  def new(%{"name" => name, "type" => type}),
    do: %__MODULE__{name: to_string(name), type: to_string(type)}
end
