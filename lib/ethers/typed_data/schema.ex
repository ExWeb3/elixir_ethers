defmodule Ethers.TypedData.Schema do
  @moduledoc """
  Compile-time DSL for declaring [EIP-712](https://eips.ethereum.org/EIPS/eip-712) typed-data
  struct types as native Elixir modules.

  Instead of hand-writing the `types`/`primary_type`/`message` maps that `Ethers.TypedData.new/1`
  consumes, you declare each EIP-712 struct type as an Elixir module and build an
  `Ethers.TypedData` straight from struct instances with `Ethers.TypedData.new/2` (or
  `new!/2`). This is a thin front-end over the existing engine - the resulting payload hashes and
  serializes identically to the map-based form.

  ## Usage

  `use Ethers.TypedData.Schema` imports the `typed_schema/1,2` and `field/2,3` macros. A
  `typed_schema` block declares an ordered list of fields; the macro generates a matching
  `defstruct` plus an introspection function `__typed_data_schema__/0`.

      defmodule Person do
        use Ethers.TypedData.Schema

        typed_schema "Person" do
          field :name, :string
          field :wallet, :address
        end
      end

      defmodule Mail do
        use Ethers.TypedData.Schema

        typed_schema "Mail" do
          field :from, Person
          field :to, Person
          field :contents, :string
        end
      end

  `typed_schema/1` derives the EIP-712 type name from the module's last segment
  (`MyApp.Messages.Mail` -> `"Mail"`); `typed_schema/2` takes an explicit name string.

  ## Field types

  The second argument to `field/2,3` is the member's type, in one of these forms:

  - a **schema module** reference (`Person`) - another module that `use`s this DSL. The EIP-712
    type string is that schema's declared type name, and it is registered (recursively) in the
    generated `types` map.
  - an **atom** (`:string`, `:address`, `:uint256`) - an atomic Solidity type; the type string is
    `Atom.to_string/1` of it.
  - a **string** (`"uint256"`, `"bytes32"`) - a literal EIP-712 type string.
  - `{:array, inner}` - a dynamic array of `inner` (`"<inner>[]"`).
  - `{:array, inner, n}` - a fixed-size array of `inner` (`"<inner>[n]"`).

  Field **order matters** - EIP-712 `encodeType` is order-sensitive, so the sequence of
  `field/2,3` calls is the source of truth (which is why the block also generates the
  `defstruct`). Type references (a schema module atom such as `Person`) are stored **unresolved**
  and resolved at runtime by the expander, not at macro-expansion time - so mutually referencing
  modules do not create compile-ordering problems.

  ## Building typed data from a schema

  Given the `Person`/`Mail` schemas above, build and hash the canonical EIP-712 `Mail` message.
  (These example modules ship in the test suite as `Ethers.Support.EIP712.Person` and
  `Ethers.Support.EIP712.Mail`.)

      iex> alias Ethers.Support.EIP712.{Mail, Person}
      iex> mail = %Mail{
      ...>   from: %Person{name: "Cow", wallet: "0xCD2a3d9F938E13CD947Ec05AbC7FE734Df8DD826"},
      ...>   to: %Person{name: "Bob", wallet: "0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB"},
      ...>   contents: "Hello, Bob!"
      ...> }
      iex> td =
      ...>   Ethers.TypedData.new!(mail,
      ...>     domain: [
      ...>       name: "Ether Mail",
      ...>       version: "1",
      ...>       chain_id: 1,
      ...>       verifying_contract: "0xCcCCccccCCCCcCCCCCCcCcCccCcCCCcCcccccccC"
      ...>     ]
      ...>   )
      iex> Ethers.TypedData.encode_type(td, "Mail")
      "Mail(Person from,Person to,string contents)Person(string name,address wallet)"
      iex> Ethers.TypedData.hash(td, :hex)
      "0xbe609aee343fb3c4b28e1df9e632fca64fcfaede20f02e86244efddf30957bd2"

  ## Introspection contract

  The generated `__typed_data_schema__/0` returns:

      {type_name :: String.t(), [%{key: atom(), name: String.t(), type: term()}]}

  where each `type` term is the raw declared type: a module atom (`Person`), an atom
  (`:string`), a string (`"uint256"`), or `{:array, inner}` / `{:array, inner, n}`. The
  per-field `:default` (used only for `defstruct`) is intentionally dropped from this tuple.
  """

  alias Ethers.TypedData.Field

  @fields_attribute :ethers_typed_data_fields

  @doc false
  defmacro __using__(_opts) do
    quote do
      import Ethers.TypedData.Schema, only: [typed_schema: 1, typed_schema: 2, field: 2, field: 3]
    end
  end

  @doc """
  Declares an EIP-712 typed-data schema.

  `typed_schema/1` derives the EIP-712 type name from the module's last segment
  (`MyApp.Messages.Mail` -> `"Mail"`). `typed_schema/2` takes an explicit type-name string.

  The `do` block must contain one or more `field/2,3` declarations, in order. The macro emits a
  `defstruct` and the `__typed_data_schema__/0` introspection function.
  """
  defmacro typed_schema(type_name \\ nil, do: block) do
    quote do
      Module.put_attribute(__MODULE__, unquote(@fields_attribute), [])

      unquote(block)

      @ethers_typed_data_schema unquote(__MODULE__).__schema__(
                                  __MODULE__,
                                  unquote(type_name)
                                )

      @ethers_typed_data_struct_fields Enum.map(
                                         Module.get_attribute(
                                           __MODULE__,
                                           unquote(@fields_attribute)
                                         ),
                                         fn field -> {field.key, field.default} end
                                       )

      defstruct @ethers_typed_data_struct_fields

      @spec __typed_data_schema__() ::
              {String.t(), [%{key: atom(), name: String.t(), type: term()}]}
      def __typed_data_schema__, do: @ethers_typed_data_schema
    end
  end

  @doc """
  Declares a single field of the enclosing `typed_schema`.

  - `key` - the struct key (must be an atom). Declaring the same `key` twice raises.
  - `type` - the raw, unresolved type term: a schema module atom (`Person`), an atom
    (`:string`, `:uint256`), a type string (`"uint256"`), or `{:array, inner}` /
    `{:array, inner, n}`.
  - `opts`:
    - `:name` - the EIP-712 member name (defaults to `to_string(key)`).
    - `:default` - the `defstruct` default for this key (defaults to `nil`).
  """
  defmacro field(key, type, opts \\ []) do
    quote do
      unquote(__MODULE__).__field__(
        __MODULE__,
        unquote(key),
        unquote(type),
        unquote(opts)
      )
    end
  end

  @doc false
  @spec __field__(module(), atom(), term(), keyword()) :: :ok
  def __field__(module, key, type, opts) do
    unless is_atom(key) do
      raise ArgumentError, "field key must be an atom, got: #{inspect(key)}"
    end

    fields = Module.get_attribute(module, @fields_attribute) || []

    if Enum.any?(fields, fn field -> field.key == key end) do
      raise ArgumentError, "field #{inspect(key)} is already declared in #{inspect(module)}"
    end

    meta = %{
      key: key,
      name: opts[:name] || to_string(key),
      type: type,
      default: Keyword.get(opts, :default)
    }

    Module.put_attribute(module, @fields_attribute, fields ++ [meta])

    :ok
  end

  @doc false
  @spec __schema__(module(), String.t() | nil) ::
          {String.t(), [%{key: atom(), name: String.t(), type: term()}]}
  def __schema__(module, type_name) do
    fields = Module.get_attribute(module, @fields_attribute) || []

    if fields == [] do
      raise ArgumentError,
            "typed_schema for #{inspect(module)} must declare at least one field"
    end

    name = type_name || module |> Module.split() |> List.last()

    meta = Enum.map(fields, fn field -> %{key: field.key, name: field.name, type: field.type} end)

    {name, meta}
  end

  @typep type_term ::
           atom()
           | String.t()
           | {:array, type_term()}
           | {:array, type_term(), pos_integer()}
  @typep field_meta :: %{key: atom(), name: String.t(), type: type_term()}
  @typep schema :: {String.t(), [field_meta()]}
  @typep types_acc :: %{types: %{String.t() => [Field.t()]}, modules: %{String.t() => module()}}

  @doc """
  Expands a schema struct instance into the parameters consumed by `Ethers.TypedData.new/1`.

  Walks the schema module referenced by `struct` transitively, resolving every referenced type
  into the EIP-712 `types` map and building the string-keyed `message` from the struct instance.

  Returns `%{types:, primary_type:, message:, domain:}` ready to hand to `Ethers.TypedData.new/1`.

  Raises `ArgumentError` if `struct` is not a schema module (does not export
  `__typed_data_schema__/0`), if a referenced type is not a schema module, or if two distinct
  modules resolve to the same EIP-712 type name with different fields.
  """
  @spec to_params(struct(), keyword()) :: %{
          types: %{String.t() => [Field.t()]},
          primary_type: String.t(),
          message: %{String.t() => term()},
          domain: keyword() | map()
        }
  def to_params(struct, opts) when is_struct(struct) do
    module = struct.__struct__
    {primary_type, _fields} = schema_of!(module)

    %{types: types} = build_types(module, %{types: %{}, modules: %{}})

    %{
      types: types,
      primary_type: primary_type,
      message: build_message(module, struct),
      domain: opts[:domain] || %{}
    }
  end

  @spec schema_of!(module()) :: schema()
  defp schema_of!(module) do
    if is_atom(module) and Code.ensure_loaded?(module) and
         function_exported?(module, :__typed_data_schema__, 0) do
      module.__typed_data_schema__()
    else
      raise ArgumentError, "not an Ethers.TypedData schema: #{inspect(module)}"
    end
  end

  @spec build_types(module(), types_acc()) :: types_acc()
  defp build_types(module, acc) do
    {type_name, fields} = schema_of!(module)

    field_structs =
      Enum.map(fields, fn field ->
        %Field{name: field.name, type: eip_type_string(field.type)}
      end)

    case Map.get(acc.types, type_name) do
      nil ->
        acc = %{
          acc
          | types: Map.put(acc.types, type_name, field_structs),
            modules: Map.put(acc.modules, type_name, module)
        }

        Enum.reduce(fields, acc, fn field, acc -> register_refs(field.type, acc) end)

      ^field_structs ->
        # Already registered (recursion dedup, or an identical duplicate declaration).
        acc

      _other ->
        raise ArgumentError,
              "EIP-712 type name collision for #{inspect(type_name)}: " <>
                "#{inspect(Map.get(acc.modules, type_name))} and #{inspect(module)} declare " <>
                "different fields under the same type name"
    end
  end

  @spec register_refs(term(), types_acc()) :: types_acc()
  defp register_refs({:array, inner}, acc), do: register_refs(inner, acc)
  defp register_refs({:array, inner, _n}, acc), do: register_refs(inner, acc)

  defp register_refs(type, acc) do
    if module_ref?(type), do: build_types(type, acc), else: acc
  end

  @spec eip_type_string(type_term()) :: String.t()
  defp eip_type_string({:array, inner}), do: eip_type_string(inner) <> "[]"
  defp eip_type_string({:array, inner, n}), do: eip_type_string(inner) <> "[#{n}]"
  defp eip_type_string(type) when is_binary(type), do: type

  defp eip_type_string(type) when is_atom(type) do
    if module_ref?(type) do
      {type_name, _fields} = schema_of!(type)
      type_name
    else
      Atom.to_string(type)
    end
  end

  @spec module_ref?(term()) :: boolean()
  defp module_ref?(type) when is_atom(type) and type not in [nil, true, false] do
    String.starts_with?(Atom.to_string(type), "Elixir.")
  end

  defp module_ref?(_type), do: false

  @spec build_message(module(), struct()) :: %{String.t() => term()}
  defp build_message(module, struct) do
    {_type_name, fields} = schema_of!(module)

    Map.new(fields, fn %{key: key, name: name, type: type} ->
      {name, to_message_value(type, Map.get(struct, key))}
    end)
  end

  @spec to_message_value(term(), term()) :: term()
  defp to_message_value({:array, inner}, list) when is_list(list),
    do: Enum.map(list, &to_message_value(inner, &1))

  defp to_message_value({:array, inner, _n}, list) when is_list(list),
    do: Enum.map(list, &to_message_value(inner, &1))

  defp to_message_value(type, value) do
    if module_ref?(type) and is_struct(value) do
      build_message(type, value)
    else
      value
    end
  end
end
