defmodule Ethers.TypedData.Encoder do
  @moduledoc false

  # The pure EIP-712 (https://eips.ethereum.org/EIPS/eip-712) encoding / hashing engine.
  #
  # This is the internal implementation of the EIP-712 algorithm (encodeType, typeHash,
  # encodeData, hashStruct, the domain separator and the final signing digest). The public
  # documented surface lives on `Ethers.TypedData`; this module holds the logic so it can be unit
  # tested in isolation.
  #
  # All hashing uses keccak-256 (`Ethers.keccak_module/0`) and all atomic member words are produced
  # with the same ABI.TypeEncoder machinery used elsewhere in the library, so encoding is
  # byte-for-byte consistent with the ABI layer.

  alias Ethers.TypedData
  alias Ethers.TypedData.Domain
  alias Ethers.TypedData.Field
  alias Ethers.Utils

  @typedoc "A 32-byte keccak-256 hash (binary)."
  @type hash :: binary()

  @doc """
  Returns the EIP-712 `encodeType` string for `type_name`.

  The primary type is rendered first, followed by every transitively referenced struct type
  sorted alphabetically by name. Each type renders as `Name(type1 field1,type2 field2,...)`.

  ## Example

      iex> td = Ethers.TypedData.new!(
      ...>   types: %{
      ...>     "Person" => [%{name: "name", type: "string"}, %{name: "wallet", type: "address"}],
      ...>     "Mail" => [
      ...>       %{name: "from", type: "Person"},
      ...>       %{name: "to", type: "Person"},
      ...>       %{name: "contents", type: "string"}
      ...>     ]
      ...>   },
      ...>   primary_type: "Mail",
      ...>   domain: [name: "Ether Mail"],
      ...>   message: %{}
      ...> )
      iex> Ethers.TypedData.Encoder.encode_type(td, "Mail")
      "Mail(Person from,Person to,string contents)Person(string name,address wallet)"
  """
  @spec encode_type(TypedData.t(), String.t()) :: String.t()
  def encode_type(%TypedData{types: types}, type_name) do
    deps = collect_dependencies(types, type_name, MapSet.new())

    sorted_deps =
      deps
      |> MapSet.delete(type_name)
      |> MapSet.to_list()
      |> Enum.sort()

    Enum.map_join([type_name | sorted_deps], &render_type(types, &1))
  end

  @doc """
  Returns `keccak256(encode_type(typed_data, type_name))` as a 32-byte binary.
  """
  @spec type_hash(TypedData.t(), String.t()) :: hash()
  def type_hash(%TypedData{} = typed_data, type_name) do
    typed_data
    |> encode_type(type_name)
    |> keccak()
  end

  @doc """
  Returns `typeHash ‖ word₁ ‖ word₂ ‖ …`, one 32-byte word per member of `type_name`.

  `value` must be a string-keyed map holding a value for each member of `type_name`.
  """
  @spec encode_data(TypedData.t(), String.t(), map()) :: binary()
  def encode_data(%TypedData{types: types} = typed_data, type_name, value) do
    fields = Map.fetch!(types, type_name)

    words =
      Enum.map_join(fields, fn %Field{name: name, type: type} ->
        encode_field(type, Map.fetch!(value, name), typed_data)
      end)

    type_hash(typed_data, type_name) <> words
  end

  @doc """
  Returns `keccak256(encode_data(typed_data, type_name, value))` as a 32-byte binary.
  """
  @spec hash_struct(TypedData.t(), String.t(), map()) :: hash()
  def hash_struct(%TypedData{} = typed_data, type_name, value) do
    typed_data
    |> encode_data(type_name, value)
    |> keccak()
  end

  @doc """
  Returns the EIP-712 domain separator (`hashStruct("EIP712Domain", domain)`) as a 32-byte binary.

  Only the present (non-nil) domain fields participate, in canonical EIP-712 order.
  """
  @spec domain_separator(TypedData.t()) :: hash()
  def domain_separator(%TypedData{domain: %Domain{} = domain}) do
    fields = Domain.present_fields(domain)

    value =
      Map.new(fields, fn %Field{name: name} -> {name, domain_field_value(domain, name)} end)

    domain_typed_data = %TypedData{
      domain: domain,
      types: %{"EIP712Domain" => fields},
      primary_type: "EIP712Domain",
      message: value
    }

    hash_struct(domain_typed_data, "EIP712Domain", value)
  end

  @doc """
  Returns the EIP-712 signing digest of `typed_data`.

  This is `keccak256(0x19 ‖ 0x01 ‖ domainSeparator ‖ hashStruct(primaryType, message))`.

  ## Parameters

  - `typed_data` - the `Ethers.TypedData` to hash.
  - `format` - either `:bin` (default, returns the raw 32-byte binary) or `:hex` (returns a
    `0x`-prefixed hex string).
  """
  @spec hash(TypedData.t()) :: hash()
  @spec hash(TypedData.t(), :bin | :hex) :: binary() | String.t()
  def hash(typed_data, format \\ :bin)

  def hash(%TypedData{} = typed_data, :bin) do
    domain_separator = domain_separator(typed_data)
    struct_hash = hash_struct(typed_data, typed_data.primary_type, typed_data.message)

    keccak(<<0x19, 0x01>> <> domain_separator <> struct_hash)
  end

  def hash(%TypedData{} = typed_data, :hex) do
    typed_data
    |> hash(:bin)
    |> Utils.hex_encode()
  end

  # --- internal helpers -----------------------------------------------------

  # Transitively collects the set of struct type names referenced from `type_name` (inclusive).
  @spec collect_dependencies(map(), String.t(), MapSet.t()) :: MapSet.t()
  defp collect_dependencies(types, type_name, acc) do
    if MapSet.member?(acc, type_name) do
      acc
    else
      acc = MapSet.put(acc, type_name)

      types
      |> Map.fetch!(type_name)
      |> Enum.reduce(acc, &collect_field_dependencies(types, &1, &2))
    end
  end

  @spec collect_field_dependencies(map(), Field.t(), MapSet.t()) :: MapSet.t()
  defp collect_field_dependencies(types, %Field{type: type}, acc) do
    base = base_type(type)

    if Map.has_key?(types, base) do
      collect_dependencies(types, base, acc)
    else
      acc
    end
  end

  @spec render_type(map(), String.t()) :: String.t()
  defp render_type(types, type_name) do
    members =
      types
      |> Map.fetch!(type_name)
      |> Enum.map_join(",", fn %Field{name: name, type: type} -> "#{type} #{name}" end)

    "#{type_name}(#{members})"
  end

  # Encodes a single member to its 32-byte word (or the intermediate hash for arrays/references).
  @spec encode_field(String.t(), term(), TypedData.t()) :: binary()
  defp encode_field(type, value, %TypedData{types: types} = typed_data) do
    cond do
      array_type?(type) ->
        element_type = element_type(type)

        value
        |> Enum.map_join(fn element -> encode_field(element_type, element, typed_data) end)
        |> keccak()

      Map.has_key?(types, base_type(type)) ->
        hash_struct(typed_data, base_type(type), value)

      true ->
        encode_atomic(type, value)
    end
  end

  @spec encode_atomic(String.t(), term()) :: binary()
  defp encode_atomic(type, value) do
    case ABI.FunctionSelector.decode_type(type) do
      :string ->
        keccak(value)

      :bytes ->
        keccak(normalize_binary(value))

      {:bytes, _size} = type_tuple ->
        encode_word(normalize_binary(value), type_tuple)

      type_tuple ->
        encode_word(Utils.prepare_arg(value, type_tuple), type_tuple)
    end
  end

  @spec encode_word(term(), ABI.FunctionSelector.type()) :: binary()
  defp encode_word(prepared, type_tuple) do
    ABI.TypeEncoder.encode([prepared], [type_tuple])
  end

  # Normalizes a `bytes`/`bytesN` value: `0x`-hex strings are decoded, raw binaries pass through.
  @spec normalize_binary(binary()) :: binary()
  defp normalize_binary(<<"0x", _rest::binary>> = hex), do: Utils.hex_decode!(hex)
  defp normalize_binary(binary) when is_binary(binary), do: binary

  @spec domain_field_value(Domain.t(), String.t()) :: binary() | non_neg_integer() | nil
  defp domain_field_value(%Domain{} = domain, "name"), do: domain.name
  defp domain_field_value(%Domain{} = domain, "version"), do: domain.version
  defp domain_field_value(%Domain{} = domain, "chainId"), do: domain.chain_id
  defp domain_field_value(%Domain{} = domain, "verifyingContract"), do: domain.verifying_contract
  defp domain_field_value(%Domain{} = domain, "salt"), do: domain.salt

  # True when `type` has an array suffix (`T[]` or `T[n]`).
  @spec array_type?(String.t()) :: boolean()
  defp array_type?(type), do: Regex.match?(~r/\[\d*\]$/, type)

  # Removes ONE array-suffix level (`T[][]` -> `T[]`, `T[n]` -> `T`).
  @spec element_type(String.t()) :: String.t()
  defp element_type(type), do: Regex.replace(~r/\[\d*\]$/, type, "")

  # Strips ALL array suffixes returning the base struct/atomic name.
  @spec base_type(String.t()) :: String.t()
  defp base_type(type), do: type |> String.split("[", parts: 2) |> hd()

  @spec keccak(binary()) :: hash()
  defp keccak(binary), do: Ethers.keccak_module().hash_256(binary)
end
