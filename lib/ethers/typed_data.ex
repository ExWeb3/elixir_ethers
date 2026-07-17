defmodule Ethers.TypedData do
  @moduledoc """
  Models an [EIP-712](https://eips.ethereum.org/EIPS/eip-712) typed structured data payload.

  An `Ethers.TypedData` mirrors the canonical `eth_signTypedData_v4` JSON shape so the same
  struct serves both hashing (the local signing pipeline) and JSON-RPC signing. It is built from:

  - `types` - a map of `type_name` (`String.t()`) to an ordered list of
    `Ethers.TypedData.Field` structs describing that struct's members. The synthetic
    `"EIP712Domain"` entry must **not** be included here - it is derived from the `domain`.
  - `primary_type` - the name (`String.t()`) of the top-level struct being signed. Must be a key
    of `types`.
  - `message` - a map of member name to value. Keys are normalized to strings internally.
  - `domain` - an `Ethers.TypedData.Domain` struct scoping the signature.

  ## Example (the canonical Mail/Person example)

  The following builds the `Mail` message from the EIP-712 specification and reproduces the
  reference `encodeType` string, domain separator and signing digest published by the spec:

      iex> typed_data =
      ...>   Ethers.TypedData.new!(
      ...>     types: %{
      ...>       "Person" => [
      ...>         %{name: "name", type: "string"},
      ...>         %{name: "wallet", type: "address"}
      ...>       ],
      ...>       "Mail" => [
      ...>         %{name: "from", type: "Person"},
      ...>         %{name: "to", type: "Person"},
      ...>         %{name: "contents", type: "string"}
      ...>       ]
      ...>     },
      ...>     primary_type: "Mail",
      ...>     domain: [
      ...>       name: "Ether Mail",
      ...>       version: "1",
      ...>       chain_id: 1,
      ...>       verifying_contract: "0xCcCCccccCCCCcCCCCCCcCcCccCcCCCcCcccccccC"
      ...>     ],
      ...>     message: %{
      ...>       "from" => %{"name" => "Cow", "wallet" => "0xCD2a3d9F938E13CD947Ec05AbC7FE734Df8DD826"},
      ...>       "to" => %{"name" => "Bob", "wallet" => "0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB"},
      ...>       "contents" => "Hello, Bob!"
      ...>     }
      ...>   )
      iex> Ethers.TypedData.encode_type(typed_data, "Mail")
      "Mail(Person from,Person to,string contents)Person(string name,address wallet)"
      iex> Ethers.TypedData.hash(typed_data, :hex)
      "0xbe609aee343fb3c4b28e1df9e632fca64fcfaede20f02e86244efddf30957bd2"
      iex> Ethers.Utils.hex_encode(Ethers.TypedData.domain_separator(typed_data))
      "0xf2cee375fa42b42143804025fc449deafd50cc031ca257e0b194a650a912090f"
  """

  alias Ethers.TypedData.Domain
  alias Ethers.TypedData.Encoder
  alias Ethers.TypedData.Field
  alias Ethers.TypedData.Schema
  alias Ethers.Utils

  @enforce_keys [:domain, :types, :primary_type, :message]
  defstruct [:domain, :types, :primary_type, :message]

  @typedoc """
  An EIP-712 typed-data payload.

  - `domain` - the `Ethers.TypedData.Domain` scoping the signature.
  - `types` - map of struct type name to ordered list of `Ethers.TypedData.Field` structs.
  - `primary_type` - the top-level struct type name being signed.
  - `message` - the message data as a map with string keys.
  """
  @type t :: %__MODULE__{
          domain: Domain.t(),
          types: %{String.t() => [Field.t()]},
          primary_type: String.t(),
          message: %{String.t() => term()}
        }

  # Matches any Solidity atomic (non-reference) base type: address, bool, string, bytes,
  # bytes1..bytes32, uintN and intN (any bit width).
  @atomic_type_regex ~r/^(address|bool|string|bytes([1-9]|[12][0-9]|3[0-2])?|u?int([0-9]+)?)$/

  @doc """
  Builds an `Ethers.TypedData` from the given parameters, normalizing and validating them.

  ## Parameters (keyword list or map)

  - `:types` - a map of type name to a list of field definitions. Each field may be a
    `%Ethers.TypedData.Field{}`, a map with atom keys (`%{name: ..., type: ...}`), or a map with
    string keys (`%{"name" => ..., "type" => ...}`). All are normalized to `Field` structs.
  - `:primary_type` - the top-level struct type name. Must exist in `:types`.
  - `:domain` - an `Ethers.TypedData.Domain` struct, or a keyword/map accepted by
    `Ethers.TypedData.Domain.new/1`.
  - `:message` - a map of member name to value. Both atom and string keys are accepted and
    normalized to string keys.

  ## Validation

  Returns `{:error, reason}` when:

  - `:primary_type` is not a key of `:types` (`{:error, {:unknown_primary_type, name}}`).
  - a member references a struct type that is not defined in `:types`
    (`{:error, {:undefined_type, name}}`).

  Otherwise returns `{:ok, %Ethers.TypedData{}}`.
  """
  @spec new(struct()) :: {:ok, t()} | {:error, term()}
  @spec new(keyword() | map()) :: {:ok, t()} | {:error, term()}
  def new(struct) when is_struct(struct), do: new(struct, [])

  def new(params) do
    params = Map.new(params)

    with {:ok, types} <- fetch(params, :types),
         {:ok, primary_type} <- fetch(params, :primary_type),
         {:ok, message} <- fetch(params, :message) do
      types = normalize_types(types)
      primary_type = to_string(primary_type)
      domain = Domain.new(Map.get(params, :domain, %{}))

      with :ok <- validate_primary_type(types, primary_type),
           :ok <- validate_references(types) do
        {:ok,
         %__MODULE__{
           domain: domain,
           types: types,
           primary_type: primary_type,
           message: normalize_message(message)
         }}
      end
    end
  end

  @doc """
  Builds an `Ethers.TypedData` from a schema struct instance (see `Ethers.TypedData.Schema`).

  Declare the EIP-712 struct types as modules with `use Ethers.TypedData.Schema`, then pass an
  instance of the top-level struct. The struct is expanded into `types`/`primary_type`/`message`
  (walking referenced schema modules transitively) and validated via `new/1`, so the result is
  identical to the equivalent map-based `new/1` call.

  `opts` may carry `:domain` (a keyword/map accepted by `Ethers.TypedData.Domain.new/1`).

  ## Example

      # given `Person`/`Mail` schema modules (see `Ethers.TypedData.Schema`)
      Ethers.TypedData.new!(
        %Mail{
          from: %Person{name: "Cow", wallet: "0xCD2a3d9F938E13CD947Ec05AbC7FE734Df8DD826"},
          to: %Person{name: "Bob", wallet: "0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB"},
          contents: "Hello, Bob!"
        },
        domain: [name: "Ether Mail", version: "1", chain_id: 1,
                 verifying_contract: "0xCcCCccccCCCCcCCCCCCcCcCccCcCCCcCcccccccC"]
      )
  """
  @spec new(struct(), keyword()) :: {:ok, t()} | {:error, term()}
  def new(struct, opts) when is_struct(struct) do
    struct |> Schema.to_params(opts) |> new()
  end

  @doc """
  Same as `new/1` but raises an `ArgumentError` on error.
  """
  @spec new!(struct()) :: t() | no_return()
  @spec new!(keyword() | map()) :: t() | no_return()
  def new!(struct) when is_struct(struct), do: new!(struct, [])

  def new!(params) do
    case new(params) do
      {:ok, typed_data} -> typed_data
      {:error, reason} -> raise ArgumentError, "invalid typed data: #{inspect(reason)}"
    end
  end

  @doc """
  Same as `new/2` but raises an `ArgumentError` on error.
  """
  @spec new!(struct(), keyword()) :: t() | no_return()
  def new!(struct, opts) when is_struct(struct) do
    case new(struct, opts) do
      {:ok, typed_data} -> typed_data
      {:error, reason} -> raise ArgumentError, "invalid typed data: #{inspect(reason)}"
    end
  end

  @spec fetch(map(), :types | :primary_type | :message) ::
          {:ok, term()} | {:error, {:missing_key, :types | :primary_type | :message}}
  defp fetch(params, key) do
    case Map.fetch(params, key) do
      {:ok, value} -> {:ok, value}
      :error -> {:error, {:missing_key, key}}
    end
  end

  @spec normalize_types(map()) :: %{String.t() => [Field.t()]}
  defp normalize_types(types) do
    Map.new(types, fn {type_name, fields} ->
      {to_string(type_name), Enum.map(fields, &Field.new/1)}
    end)
  end

  @spec normalize_message(term()) :: term()
  defp normalize_message(message) when is_map(message) and not is_struct(message) do
    Map.new(message, fn {key, value} -> {to_string(key), normalize_message(value)} end)
  end

  defp normalize_message(list) when is_list(list), do: Enum.map(list, &normalize_message/1)

  defp normalize_message(value), do: value

  @spec validate_primary_type(%{String.t() => [Field.t()]}, String.t()) ::
          :ok | {:error, {:unknown_primary_type, String.t()}}
  defp validate_primary_type(types, primary_type) do
    if Map.has_key?(types, primary_type) do
      :ok
    else
      {:error, {:unknown_primary_type, primary_type}}
    end
  end

  @spec validate_references(%{String.t() => [Field.t()]}) ::
          :ok | {:error, {:undefined_type, String.t()}}
  defp validate_references(types) do
    types
    |> Enum.flat_map(fn {_name, fields} -> fields end)
    |> Enum.reduce_while(:ok, fn %Field{type: type}, :ok ->
      base = base_type(type)

      cond do
        atomic_type?(base) -> {:cont, :ok}
        Map.has_key?(types, base) -> {:cont, :ok}
        true -> {:halt, {:error, {:undefined_type, base}}}
      end
    end)
  end

  @doc false
  # Strips array suffixes (`[]`, `[n]`) returning the base type name.
  @spec base_type(String.t()) :: String.t()
  def base_type(type) do
    case String.split(type, "[", parts: 2) do
      [base | _] -> base
    end
  end

  @spec atomic_type?(String.t()) :: boolean()
  defp atomic_type?(base), do: Regex.match?(@atomic_type_regex, base)

  @doc """
  Serializes an `Ethers.TypedData` into the canonical `eth_signTypedData_v4` JSON-compatible map.

  The returned map uses string keys and JSON-ready scalar values so it can be encoded with
  `Jason.encode!/1` and handed to a wallet / node. Its shape is:

      %{
        "types" => %{
          "EIP712Domain" => [%{"name" => ..., "type" => ...}, ...],
          <primary type and every referenced type> => [%{"name" => ..., "type" => ...}, ...]
        },
        "primaryType" => "Mail",
        "domain" => %{...present domain fields...},
        "message" => %{...}
      }

  ## Value serialization

  - `address` - `0x` checksummed hex (accepts a `0x`-hex string or a 20-byte binary).
  - `bytesN` / `bytes` - `0x` hex (accepts a `0x`-hex string or a binary).
  - `uintN` / `intN` - decimal string (accepts an integer, a decimal string, or a `0x`-hex
    string). Always serialized as a decimal string for full `uint256`-range interoperability.
  - `bool` / `string` - passed through unchanged.
  - reference struct types - recursed into as nested maps.
  - array types (`T[]` / `T[n]`, including nested arrays) - serialized as lists element by element.

  The `"EIP712Domain"` entry is derived from the domain's present (non-nil) fields in canonical
  order; the caller must not include it in `types`.
  """
  @spec to_eip712_json(t()) :: %{String.t() => term()}
  def to_eip712_json(%__MODULE__{} = typed_data) do
    %__MODULE__{
      domain: domain,
      types: types,
      primary_type: primary_type,
      message: message
    } = typed_data

    %{
      "types" => build_types_json(domain, types),
      "primaryType" => primary_type,
      "domain" => serialize_domain(domain),
      "message" => serialize_struct(primary_type, message, types)
    }
  end

  @doc """
  Returns the EIP-712 `encodeType` string for `type_name` (e.g.
  `"Mail(Person from,Person to,string contents)Person(string name,address wallet)"`).
  """
  @spec encode_type(t(), String.t()) :: String.t()
  defdelegate encode_type(typed_data, type_name), to: Encoder

  @doc """
  Returns the 32-byte `typeHash` (`keccak256(encodeType(type_name))`).
  """
  @spec type_hash(t(), String.t()) :: binary()
  defdelegate type_hash(typed_data, type_name), to: Encoder

  @doc """
  Returns the EIP-712 `encodeData` bytes for `value` as type `type_name`
  (`typeHash ‖ enc(memberᵢ)…`).
  """
  @spec encode_data(t(), String.t(), term()) :: binary()
  defdelegate encode_data(typed_data, type_name, value), to: Encoder

  @doc """
  Returns the 32-byte `hashStruct(type_name, value)` = `keccak256(encodeData(type_name, value))`.
  """
  @spec hash_struct(t(), String.t(), term()) :: binary()
  defdelegate hash_struct(typed_data, type_name, value), to: Encoder

  @doc """
  Returns the 32-byte EIP-712 `domainSeparator` (`hashStruct("EIP712Domain", domain)`).
  """
  @spec domain_separator(t()) :: binary()
  defdelegate domain_separator(typed_data), to: Encoder

  @doc """
  Returns the EIP-712 signing digest
  `keccak256(0x19 ‖ 0x01 ‖ domainSeparator ‖ hashStruct(primaryType, message))`.

  With `:bin` (default) returns the raw 32-byte binary; with `:hex` returns `0x`-prefixed hex.
  """
  @spec hash(t()) :: binary()
  defdelegate hash(typed_data), to: Encoder

  @doc """
  Returns the EIP-712 signing digest of `typed_data` in the requested `format`.

  With `:bin` returns the raw 32-byte binary; with `:hex` returns a `0x`-prefixed hex string.
  See `hash/1` for the digest definition.
  """
  @spec hash(t(), :bin | :hex) :: binary()
  defdelegate hash(typed_data, format), to: Encoder

  @doc """
  Recovers the signer address from an EIP-712 typed-data payload and its signature.

  The signing digest is recomputed from `typed_data` (via `hash/1`) and the signer's public key
  is recovered from the signature, then converted to its checksummed `0x` address.

  `signature` may be given as a `0x`-prefixed hex string (130 hex chars) or a raw 65-byte binary
  (`r ‖ s ‖ v`).

  ## Returns

  - a checksummed `0x` address string on success.
  - `{:error, reason}` if the public key could not be recovered.

  ## Examples

  ```elixir
  {:ok, sig} =
    Ethers.sign_typed_data(typed_data,
      signer: Ethers.Signer.Local,
      signer_opts: [private_key: key]
    )

  Ethers.TypedData.recover_signer(typed_data, sig)
  #=> "0x90F8bf6A479f320ead074411a4B0e7944Ea8c9C1"
  ```
  """
  @spec recover_signer(t(), binary()) :: Ethers.Types.t_address() | {:error, term()}
  def recover_signer(%__MODULE__{} = typed_data, signature) do
    digest = hash(typed_data)

    <<r::binary-size(32), s::binary-size(32), v::integer>> = normalize_signature(signature)

    case Ethers.secp256k1_module().recover(digest, r, s, v - 27) do
      {:ok, public_key} -> Utils.public_key_to_address(public_key)
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Checks whether `signature` over `typed_data` was produced by `expected_address`.

  Recovers the signer via `recover_signer/2` and compares it to `expected_address`. The
  comparison is done on the decoded 20-byte addresses, so checksum/case differences are ignored.

  `signature` may be a `0x`-prefixed hex string or a raw 65-byte binary.

  ## Examples

  ```elixir
  Ethers.TypedData.valid_signature?(typed_data, sig, "0x90F8bf6A479f320ead074411a4B0e7944Ea8c9C1")
  #=> true
  ```
  """
  @spec valid_signature?(t(), binary(), Ethers.Types.t_address()) :: boolean()
  def valid_signature?(%__MODULE__{} = typed_data, signature, expected_address) do
    case recover_signer(typed_data, signature) do
      {:error, _reason} ->
        false

      recovered ->
        Utils.decode_address!(recovered) == Utils.decode_address!(expected_address)
    end
  end

  @spec normalize_signature(binary()) :: binary()
  defp normalize_signature("0x" <> _ = hex), do: Utils.hex_decode!(hex)
  defp normalize_signature(binary) when is_binary(binary), do: binary

  @spec build_types_json(Domain.t(), %{String.t() => [Field.t()]}) :: %{String.t() => [map()]}
  defp build_types_json(domain, types) do
    struct_entries =
      Map.new(types, fn {name, fields} -> {name, Enum.map(fields, &field_json/1)} end)

    domain_entry = Enum.map(Domain.present_fields(domain), &field_json/1)

    Map.put(struct_entries, "EIP712Domain", domain_entry)
  end

  @spec field_json(Field.t()) :: %{String.t() => String.t()}
  defp field_json(%Field{name: name, type: type}), do: %{"name" => name, "type" => type}

  @spec serialize_domain(Domain.t()) :: %{String.t() => term()}
  defp serialize_domain(%Domain{} = domain) do
    values = %{
      "name" => domain.name,
      "version" => domain.version,
      "chainId" => domain.chain_id,
      "verifyingContract" => domain.verifying_contract,
      "salt" => domain.salt
    }

    Map.new(Domain.present_fields(domain), fn %Field{name: name, type: type} ->
      {name, serialize_atomic(type, Map.fetch!(values, name))}
    end)
  end

  @spec serialize_value(String.t(), term(), %{String.t() => [Field.t()]}) :: term()
  defp serialize_value(type, value, types) do
    cond do
      array_type?(type) ->
        element_type = array_element_type(type)
        Enum.map(value, &serialize_value(element_type, &1, types))

      Map.has_key?(types, type) ->
        serialize_struct(type, value, types)

      true ->
        serialize_atomic(type, value)
    end
  end

  @spec serialize_struct(String.t(), map(), %{String.t() => [Field.t()]}) :: %{
          String.t() => term()
        }
  defp serialize_struct(type, value, types) do
    fields = Map.fetch!(types, type)

    Map.new(fields, fn %Field{name: name, type: field_type} ->
      {name, serialize_value(field_type, Map.fetch!(value, name), types)}
    end)
  end

  @spec serialize_atomic(String.t(), term()) :: term()
  defp serialize_atomic("address", value), do: value |> to_binary() |> Utils.encode_address!()
  defp serialize_atomic("bool", value), do: value
  defp serialize_atomic("string", value), do: value
  defp serialize_atomic("bytes", value), do: value |> to_binary() |> Utils.hex_encode()

  defp serialize_atomic(type, value) do
    cond do
      String.starts_with?(type, "bytes") -> value |> to_binary() |> Utils.hex_encode()
      String.starts_with?(type, "uint") -> serialize_integer(value)
      String.starts_with?(type, "int") -> serialize_integer(value)
    end
  end

  @spec to_binary(binary()) :: binary()
  defp to_binary("0x" <> _ = hex), do: Utils.hex_decode!(hex)
  defp to_binary(binary) when is_binary(binary), do: binary

  @spec serialize_integer(integer() | String.t()) :: String.t()
  defp serialize_integer(value) when is_integer(value), do: Integer.to_string(value)

  defp serialize_integer("0x" <> _ = value),
    do: value |> Utils.hex_to_integer!() |> Integer.to_string()

  defp serialize_integer(value) when is_binary(value), do: value

  @spec array_type?(String.t()) :: boolean()
  defp array_type?(type), do: String.ends_with?(type, "]")

  @spec array_element_type(String.t()) :: String.t()
  defp array_element_type(type) do
    [_, element_type] = Regex.run(~r/^(.*)\[[^\]]*\]$/, type)
    element_type
  end
end
