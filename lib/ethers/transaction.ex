defmodule Ethers.Transaction do
  @moduledoc """
  Transaction struct and helper functions for handling EVM transactions.

  This module provides functionality to:
  - Create and manipulate transaction structs
  - Encode transactions for network transmission
  - Handle different transaction types

  Supported transaction types:
  - `Ethers.Transaction.Legacy` - Legacy (type 0) transactions, with
    [EIP-155](https://eips.ethereum.org/EIPS/eip-155) replay protection when `chain_id` is set
  - `Ethers.Transaction.Eip2930` - [EIP-2930](https://eips.ethereum.org/EIPS/eip-2930) access
    list (type 1) transactions
  - `Ethers.Transaction.Eip1559` - [EIP-1559](https://eips.ethereum.org/EIPS/eip-1559) fee
    market (type 2) transactions, the default when sending or signing transactions
  - `Ethers.Transaction.Eip4844` - [EIP-4844](https://eips.ethereum.org/EIPS/eip-4844) blob
    (type 3) transactions. Transaction envelope only: blob sidecars are not supported, so these
    cannot be broadcast
  - `Ethers.Transaction.Eip7702` - [EIP-7702](https://eips.ethereum.org/EIPS/eip-7702) set code
    (type 4) transactions

  Signed transactions of any type are wrapped in `Ethers.Transaction.Signed`.

  Transactions of any other type (for example OP-stack deposit transactions, type `0x7e`) read
  with `from_rpc_map/1` or `decode/1` are returned undecoded as `Ethers.Transaction.Unknown`.
  """

  alias Ethers.Authorization
  alias Ethers.Transaction.Eip1559
  alias Ethers.Transaction.Eip2930
  alias Ethers.Transaction.Eip4844
  alias Ethers.Transaction.Eip7702
  alias Ethers.Transaction.Legacy
  alias Ethers.Transaction.Metadata
  alias Ethers.Transaction.Protocol, as: TxProtocol
  alias Ethers.Transaction.Signed
  alias Ethers.Transaction.Unknown
  alias Ethers.Utils

  @default_transaction_types [Eip1559, Eip2930, Eip4844, Eip7702, Legacy]

  @transaction_types Application.compile_env(
                       :ethers,
                       :transaction_types,
                       @default_transaction_types
                     )

  @default_transaction_type Eip1559

  @rpc_fields %{
    access_list: :accessList,
    authorization_list: :authorizationList,
    blob_versioned_hashes: :blobVersionedHashes,
    chain_id: :chainId,
    gas_price: :gasPrice,
    max_fee_per_blob_gas: :maxFeePerBlobGas,
    max_fee_per_gas: :maxFeePerGas,
    max_priority_fee_per_gas: :maxPriorityFeePerGas
  }

  # Margin precision is 0.01% (12345 = 123.45%)
  @margin_precision 10_000

  # Fields auto-filled through Ethers.estimate_fees/1 when the RPC client supports it
  @fee_estimation_fields [:max_fee_per_gas, :max_priority_fee_per_gas]

  @typedoc """
  EVM Transaction type
  """
  @type t :: t_payload() | Signed.t() | Unknown.t()

  @typedoc """
  EVM Transaction payload type
  """
  @type t_payload ::
          unquote(
            @transaction_types
            |> Enum.map(&{{:., [], [{:__aliases__, [alias: false], [&1]}, :t]}, [], []})
            |> Enum.reduce(&{:|, [], [&1, &2]})
          )

  @doc "Creates a new transaction struct with the given parameters."
  @callback new(map()) :: {:ok, t()} | {:error, reason :: atom()}

  @doc "Returns a list of fields that can be auto-fetched from the network."
  @callback auto_fetchable_fields() :: [atom()]

  @doc "Returns the type envelope for the transaction."
  @callback type_envelope() :: binary()

  @doc "Returns the type ID for the transaction. e.g Legacy: 0, EIP-1559: 2"
  @callback type_id() :: non_neg_integer()

  @doc "Constructs a transaction from a decoded RLP list"
  @callback from_rlp_list([binary() | [binary()]]) ::
              {:ok, t(), rest :: [binary() | [binary()]]} | {:error, reason :: term()}

  @doc """
  Creates a new transaction struct with the given parameters.

  Type of transaction is determined by the required `type` field in the params map. Returns
  `{:error, :missing_type}` when it is missing, `{:error, :missing_<field>}` (e.g.
  `{:error, :missing_chain_id}`) when a field required by the type is missing and
  `{:error, reason}` when a field is invalid.

  ## Examples

      iex> Ethers.Transaction.new(%{
      ...>   type: Ethers.Transaction.Eip1559,
      ...>   chain_id: 1,
      ...>   nonce: 0,
      ...>   gas: 21_000,
      ...>   max_fee_per_gas: 30_000_000_000,
      ...>   max_priority_fee_per_gas: 1_000_000_000,
      ...>   to: "0x90F8bf6A479f320ead074411a4B0e7944Ea8c9C1",
      ...>   value: 1
      ...> })
      {:ok,
       %Ethers.Transaction.Eip1559{
         chain_id: 1,
         nonce: 0,
         max_priority_fee_per_gas: 1_000_000_000,
         max_fee_per_gas: 30_000_000_000,
         gas: 21_000,
         to: "0x90F8bf6A479f320ead074411a4B0e7944Ea8c9C1",
         value: 1,
         input: "",
         access_list: []
       }}
  """
  @spec new(map()) :: {:ok, t()} | {:error, reason :: term()}
  def new(params) do
    case Map.fetch(params, :type) do
      {:ok, type} when type in @transaction_types ->
        params
        |> type.new()
        |> maybe_wrap_signed(params)

      {:ok, _type} ->
        {:error, :unsupported_transaction_type}

      :error ->
        {:error, :missing_type}
    end
  end

  defp maybe_wrap_signed({:ok, transaction}, params) when not is_nil(transaction) do
    case Map.get(params, :signature_r) do
      nil ->
        {:ok, transaction}

      _sig_r ->
        params
        |> Map.put(:payload, transaction)
        |> Signed.new()
    end
  end

  defp maybe_wrap_signed({:error, reason}, _params), do: {:error, reason}

  @doc """
  Fills missing transaction fields with default values from the network based on transaction type.
  When `params` has no `:type`, it is set to `Ethers.Transaction.Eip1559`.

  Missing `max_fee_per_gas` and `max_priority_fee_per_gas` values are estimated from recent
  blocks with `Ethers.estimate_fees/1` (`eth_feeHistory`). When the RPC client does not
  support `eth_feeHistory` (or the node returns no usable data), they fall back to the
  legacy estimation based on `eth_gasPrice` and `eth_maxPriorityFeePerGas`.

  ## Parameters
    - `params` - Updated Transaction params
    - `opts` - Options to pass to the RPC client

  ## Returns
    - `{:ok, params}` - Filled transaction params map
    - `{:error, reason}` - If fetching defaults fails
  """
  @spec add_auto_fetchable_fields(map(), keyword()) :: {:ok, map()} | {:error, term()}
  def add_auto_fetchable_fields(params, opts) do
    params = Map.put_new(params, :type, @default_transaction_type)

    missing_keys = Enum.reject(params.type.auto_fetchable_fields(), &Map.get(params, &1))

    {params, missing_keys} = maybe_estimate_fees(params, missing_keys, opts)

    {keys, actions} =
      missing_keys
      |> Enum.map(&{&1, fill_action(&1, params)})
      |> Enum.unzip()

    case actions do
      [] ->
        {:ok, params}

      _ ->
        with {:ok, results} <- Ethers.batch(actions, opts),
             {:ok, results} <- post_process(keys, results, []) do
          {:ok, Map.merge(params, results)}
        end
    end
  end

  defp maybe_estimate_fees(params, missing_keys, opts) do
    missing_fee_keys = Enum.filter(missing_keys, &(&1 in @fee_estimation_fields))

    with [_ | _] <- missing_fee_keys,
         true <- fee_history_supported?(opts),
         {:ok, fees} <- Ethers.estimate_fees(opts) do
      {Map.merge(params, Map.take(fees, missing_fee_keys)), missing_keys -- missing_fee_keys}
    else
      # Nothing to estimate or no eth_feeHistory support - fall back to the legacy
      # gas price based fill actions for any missing fee field
      _no_estimation -> {params, missing_keys}
    end
  end

  defp fee_history_supported?(opts) do
    {rpc_client, _rpc_opts} = Ethers.get_rpc_client(opts)

    Code.ensure_loaded?(rpc_client) and function_exported?(rpc_client, :eth_fee_history, 4)
  end

  @doc """
  Encodes a transaction for network transmission.

  Handles all supported transaction types: Legacy (including EIP-155), EIP-2930, EIP-1559,
  EIP-4844 and EIP-7702. An `Ethers.Transaction.Signed` transaction is encoded with its
  signature. An unsigned transaction is encoded as its signing payload, whose keccak hash is
  what gets signed (for EIP-155 legacy transactions it ends with `chain_id, 0, 0`, which
  `decode/1` reads back as the unsigned transaction). EIP-4844 transactions are encoded without
  a blob sidecar (see `Ethers.Transaction.Eip4844`).

  An `Ethers.Transaction.Unknown` transaction is encoded as its type byte followed by its
  `raw_payload`, the bytes it was decoded from. One without `raw_payload` (read with
  `from_rpc_map/1`) raises `ArgumentError`.

  ## Parameters
    - `transaction` - Transaction struct to encode

  ## Returns
    - `binary` - RLP encoded transaction with appropriate type envelope
  """
  @spec encode(t()) :: binary()
  def encode(%Unknown{raw_payload: raw_payload} = transaction) when is_binary(raw_payload),
    do: TxProtocol.type_envelope(transaction) <> raw_payload

  def encode(%Unknown{} = transaction) do
    Unknown.raise_unsupported(
      transaction,
      "#{inspect(Unknown)} without raw_payload cannot be encoded"
    )
  end

  def encode(%mod{} = transaction) do
    mode = if mod == Signed, do: :payload, else: :hash

    transaction
    |> TxProtocol.to_rlp_list(mode)
    |> ExRLP.encode()
    |> prepend_type_envelope(transaction)
  end

  @doc """
  Decodes a raw transaction from a binary or hex-encoded string.

  Transaction strings must be prefixed with "0x" for hex-encoded inputs.
  Handles legacy and all supported typed transactions (EIP-2930, EIP-1559, EIP-4844 and
  EIP-7702). Signed transactions are returned wrapped in `Ethers.Transaction.Signed`, unsigned
  ones (including the EIP-155 legacy signing payload, see `encode/1`) as the bare transaction
  struct. EIP-4844 transactions are decoded from the transaction envelope only (without a blob
  sidecar). Malformed input returns an error instead of raising.

  A first byte in `0x01..0x7f` that is not a registered transaction type (for example an
  OP-stack deposit transaction, type `0x7e`) returns an `Ethers.Transaction.Unknown` with the
  rest of the bytes, undecoded and unvalidated, in `raw_payload`.

  ## Parameters
    - `raw_transaction` - Raw transaction data as a binary or hex string starting with "0x"

  ## Returns
    - `{:ok, transaction}` - Decoded transaction struct
    - `{:error, reason}` - The input is not a valid transaction, with `reason` one of:
      - `:invalid_hex` - invalid hex string
      - `:invalid_rlp` - invalid RLP, or trailing bytes after the transaction
      - `:unsupported_transaction_type` - a first byte of `0x00` (legacy transactions have no
        type byte)
      - `:transaction_decode_failed` - fields of the wrong shape, kind or size
      - `:invalid_address` - a `to` address that is not 20 bytes
      - `:missing_to_address` - an EIP-7702 transaction without `to`
      - `:signature_decode_failed` - malformed signature fields
      - `:authorization_decode_failed` - a malformed EIP-7702 authorization
  """
  @spec decode(String.t() | binary()) :: {:ok, t()} | {:error, term()}
  def decode("0x" <> raw_transaction) do
    case Utils.hex_decode(raw_transaction) do
      {:ok, hex_decoded} -> decode(hex_decoded)
      :error -> {:error, :invalid_hex}
    end
  end

  def decode(raw_transaction_bin) when is_binary(raw_transaction_bin) do
    case split_type_envelope(raw_transaction_bin) do
      {:ok, Unknown, type_id, raw_payload} ->
        {:ok, %Unknown{type_id: type_id, raw_payload: raw_payload}}

      {:ok, module, rlp_binary} ->
        with {:ok, rlp_list} <- decode_rlp_list(rlp_binary),
             {:ok, transaction, signature} <- module.from_rlp_list(rlp_list) do
          maybe_decode_signature(transaction, signature)
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @transaction_types
  |> Enum.reject(&(&1.type_envelope() == ""))
  |> Enum.each(fn module ->
    type_envelope = module.type_envelope()

    defp split_type_envelope(<<unquote(type_envelope)::binary, rest::binary>>),
      do: {:ok, unquote(module), rest}
  end)

  # EIP-2718: a first byte in 0x00..0x7f is a transaction type, a legacy transaction is an RLP list.
  # Type 0 is legacy, which has no type byte.
  defp split_type_envelope(<<0, _rest::binary>>), do: {:error, :unsupported_transaction_type}

  defp split_type_envelope(<<type, raw_payload::binary>>) when type <= 0x7F,
    do: {:ok, Unknown, type, raw_payload}

  defp split_type_envelope(legacy_transaction), do: {:ok, Legacy, legacy_transaction}

  # ExRLP.decode/1 silently mixes trailing bytes into its result, so the list header has to
  # span the whole input before decoding
  defp decode_rlp_list(<<prefix, _rest::binary>> = rlp_binary) when prefix >= 0xC0 do
    if rlp_list_spans_input?(rlp_binary) do
      {:ok, ExRLP.decode(rlp_binary)}
    else
      {:error, :invalid_rlp}
    end
  rescue
    # ExRLP raises either of these on truncated or otherwise malformed items
    _error in [ExRLP.DecodeError, MatchError] -> {:error, :invalid_rlp}
  end

  defp decode_rlp_list(<<>>), do: {:error, :invalid_rlp}
  defp decode_rlp_list(_not_a_list), do: {:error, :transaction_decode_failed}

  defp rlp_list_spans_input?(<<prefix, payload::binary>>) when prefix <= 0xF7,
    do: byte_size(payload) == prefix - 0xC0

  defp rlp_list_spans_input?(<<prefix, rest::binary>>) do
    length_size = prefix - 0xF7

    byte_size(rest) >= length_size and
      byte_size(rest) - length_size == :binary.decode_unsigned(binary_part(rest, 0, length_size))
  end

  defp maybe_decode_signature(transaction, rlp_list) do
    case Signed.from_rlp_list(rlp_list, transaction) do
      {:ok, signed_transaction} -> {:ok, signed_transaction}
      {:error, :no_signature} -> {:ok, transaction}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Calculates the transaction hash.

  ## Parameters
  - `transaction` - Transaction struct to hash
  - `format` - Format to return the hash in. Either `:hex` or `:bin`. (default: `:hex`)

  ## Returns Either
  - `binary` - Transaction hash in binary format (when `format` is `:bin`)
  - `String.t()` - Transaction hash in hex format prefixed with "0x" (when `format` is `:hex`)

  The hash of an `Ethers.Transaction.Unknown` transaction is the keccak hash of its encoding
  (see `encode/1`). One without `raw_payload` (read with `from_rpc_map/1`) raises
  `ArgumentError`, the hash reported by the node is in its `rpc_map`.
  """
  @spec transaction_hash(t(), :bin | :hex) :: binary() | String.t()
  def transaction_hash(transaction, format \\ :hex)

  def transaction_hash(%Unknown{raw_payload: nil} = transaction, _format) do
    Unknown.raise_unsupported(
      transaction,
      ~s(#{inspect(Unknown)} without raw_payload cannot be hashed, ) <>
        ~s(the hash reported by the node is in rpc_map["hash"])
    )
  end

  def transaction_hash(transaction, format) do
    hash_bin =
      transaction
      |> encode()
      |> Ethers.keccak_module().hash_256()

    case format do
      :bin -> hash_bin
      :hex -> Utils.hex_encode(hash_bin)
    end
  end

  @doc """
  Converts a map (typically from JSON-RPC response) into a Transaction struct.

  Handles different field naming conventions and transaction types.

  A transaction of a type that is not registered (for example an OP-stack deposit transaction,
  type `0x7e`) is returned as an `Ethers.Transaction.Unknown` holding the map, unchanged, in
  `rpc_map` and its block metadata in `metadata`.

  ## Parameters
    - `tx` - Map containing transaction data. Keys can be camelCase strings or atoms.
    (e.g `:chainId`, `"gasPrice"`)

  ## Returns
    - `{:ok, transaction}` - Converted transaction struct
    - `{:error, :invalid_type}` - If the transaction type is not a hex quantity
    - `{:error, reason}` - If transaction fields are missing or invalid (see `new/1`)
  """
  @spec from_rpc_map(map()) :: {:ok, t()} | {:error, term()}
  def from_rpc_map(tx) do
    case decode_type(from_map_value(tx, :type)) do
      {:ok, Unknown, type_id} -> {:ok, Unknown.from_rpc_map(tx, type_id)}
      {:ok, type} -> new(rpc_map_to_params(tx, type))
      {:error, reason} -> {:error, reason}
    end
  end

  # Converts from RPC-style field names to EVM field names
  defp rpc_map_to_params(tx, type) do
    %{
      access_list: tx |> from_map_value(:accessList) |> from_rpc_access_list(),
      authorization_list:
        tx |> from_map_value(:authorizationList) |> from_rpc_authorization_list(),
      blob_versioned_hashes:
        tx |> from_map_value(:blobVersionedHashes) |> from_rpc_blob_versioned_hashes(),
      block_hash: from_map_value(tx, :blockHash),
      block_number: from_map_value_int(tx, :blockNumber),
      chain_id: from_map_value_int(tx, :chainId),
      input: from_map_value_bin(tx, :input) || from_map_value_bin(tx, :data) || "",
      from: from_map_value(tx, :from),
      gas: from_map_value_int(tx, :gas),
      gas_price: from_map_value_int(tx, :gasPrice),
      hash: from_map_value(tx, :hash),
      max_fee_per_blob_gas: from_map_value_int(tx, :maxFeePerBlobGas),
      max_fee_per_gas: from_map_value_int(tx, :maxFeePerGas),
      max_priority_fee_per_gas: from_map_value_int(tx, :maxPriorityFeePerGas),
      nonce: from_map_value_int(tx, :nonce),
      signature_r: from_map_value_bin(tx, :r),
      signature_s: from_map_value_bin(tx, :s),
      signature_y_parity_or_v: from_map_value_int(tx, :yParity) || from_map_value_int(tx, :v),
      to: from_map_value(tx, :to),
      transaction_index: from_map_value_int(tx, :transactionIndex),
      value: from_map_value_int(tx, :value),
      type: type
    }
  end

  @doc """
  Converts a Transaction struct into a map suitable for JSON-RPC.

  A signed transaction is converted to the payload's map plus its signature (`r`, `s`,
  `yParity` and `v`, or only `v` for legacy transactions) and any block metadata it carries
  (`blockHash`, `blockNumber`, `transactionIndex`), so it reads back with `from_rpc_map/1`.

  ## Parameters
  - `transaction` - Transaction struct to convert

  ## Returns
  - map containing transaction parameters with RPC field names and "0x" prefixed hex values

  Raises `ArgumentError` if a field holds a value that has no JSON-RPC representation, and for an
  `Ethers.Transaction.Unknown` transaction (one read with `from_rpc_map/1` keeps the map in
  `rpc_map`).
  """
  @spec to_rpc_map(t()) :: map()
  def to_rpc_map(%Unknown{} = transaction) do
    Unknown.raise_unsupported(
      transaction,
      "#{inspect(Unknown)} cannot be converted to an RPC map"
    )
  end

  def to_rpc_map(%Signed{payload: payload} = signed_transaction) do
    payload
    |> to_rpc_map()
    |> Map.merge(signature_rpc_fields(signed_transaction))
    |> Map.merge(metadata_rpc_fields(signed_transaction.metadata))
  end

  def to_rpc_map(transaction) do
    transaction
    |> then(fn
      %_{} = t -> Map.from_struct(t)
      t -> t
    end)
    |> Map.new(fn {field, value} ->
      {Map.get(@rpc_fields, field, field), to_rpc_value(field, value)}
    end)
    |> Map.put(
      :type,
      transaction
      |> TxProtocol.type_id()
      |> Utils.integer_to_hex()
    )
  end

  defp to_rpc_value(_field, nil), do: nil
  defp to_rpc_value(field, "0x" <> _ = value) when field in [:from, :to, :block_hash], do: value

  defp to_rpc_value(field, input) when field in [:data, :input] and is_binary(input),
    do: Utils.hex_encode(input)

  defp to_rpc_value(_field, value) when is_integer(value), do: Utils.integer_to_hex(value)

  defp to_rpc_value(:access_list, access_list) when is_list(access_list),
    do: Enum.map(access_list, &encode_access_list_entry/1)

  defp to_rpc_value(:authorization_list, authorization_list) when is_list(authorization_list),
    do: Enum.map(authorization_list, &encode_authorization/1)

  defp to_rpc_value(:blob_versioned_hashes, hashes) when is_list(hashes) do
    Enum.map(hashes, fn
      <<_::binary-32>> = hash -> Utils.hex_encode(hash)
      hash -> raise_unsupported_rpc_value(:blob_versioned_hashes, hash)
    end)
  end

  # Type will get replaced with hex value
  defp to_rpc_value(:type, type) when is_atom(type), do: type

  defp to_rpc_value(field, value), do: raise_unsupported_rpc_value(field, value)

  defp encode_access_list_entry([<<_::binary-20>> = address, storage_keys] = entry)
       when is_list(storage_keys) do
    %{
      address: Utils.encode_address!(address),
      storageKeys:
        Enum.map(storage_keys, fn
          <<_::binary-32>> = storage_key -> Utils.hex_encode(storage_key)
          _storage_key -> raise_unsupported_rpc_value(:access_list, entry)
        end)
    }
  end

  defp encode_access_list_entry(entry), do: raise_unsupported_rpc_value(:access_list, entry)

  defp encode_authorization(%Authorization.Signed{authorization: authorization} = signed) do
    %{
      chainId: Utils.integer_to_hex(authorization.chain_id),
      address: authorization.address,
      nonce: Utils.integer_to_hex(authorization.nonce),
      yParity: Utils.integer_to_hex(signed.signature_y_parity),
      r: signature_to_rpc_quantity(:authorization_list, signed.signature_r),
      s: signature_to_rpc_quantity(:authorization_list, signed.signature_s)
    }
  end

  defp encode_authorization(authorization),
    do: raise_unsupported_rpc_value(:authorization_list, authorization)

  defp signature_rpc_fields(%Signed{payload: payload} = signed_transaction) do
    y_parity_or_v =
      to_rpc_value(:signature_y_parity_or_v, signed_transaction.signature_y_parity_or_v)

    fields = %{
      r: signature_to_rpc_quantity(:signature_r, signed_transaction.signature_r),
      s: signature_to_rpc_quantity(:signature_s, signed_transaction.signature_s),
      v: y_parity_or_v
    }

    case payload do
      %Legacy{} -> fields
      _typed -> Map.put(fields, :yParity, y_parity_or_v)
    end
  end

  defp signature_to_rpc_quantity(_field, value) when is_binary(value),
    do: value |> :binary.decode_unsigned() |> Utils.integer_to_hex()

  defp signature_to_rpc_quantity(field, value), do: raise_unsupported_rpc_value(field, value)

  defp metadata_rpc_fields(nil), do: %{}

  defp metadata_rpc_fields(%Metadata{} = metadata) do
    [
      blockHash: to_rpc_value(:block_hash, metadata.block_hash),
      blockNumber: to_rpc_value(:block_number, metadata.block_number),
      transactionIndex: to_rpc_value(:transaction_index, metadata.transaction_index)
    ]
    |> Enum.reject(fn {_field, value} -> is_nil(value) end)
    |> Map.new()
  end

  @spec raise_unsupported_rpc_value(atom(), term()) :: no_return()
  defp raise_unsupported_rpc_value(field, value) do
    raise ArgumentError,
          "Unsupported value #{inspect(value)} for transaction field #{inspect(field)}"
  end

  @doc false
  @deprecated "Use Transaction.Signed.calculate_y_parity_or_v/2 instead"
  defdelegate calculate_y_parity_or_v(tx, recovery_id), to: Signed

  defp prepend_type_envelope(encoded_tx, transaction) do
    TxProtocol.type_envelope(transaction) <> encoded_tx
  end

  defp fill_action(:chain_id, _tx), do: :chain_id
  defp fill_action(:nonce, tx), do: {:get_transaction_count, tx.from, block: "latest"}
  defp fill_action(:max_fee_per_gas, _tx), do: :gas_price
  defp fill_action(:max_priority_fee_per_gas, _tx), do: :max_priority_fee_per_gas
  defp fill_action(:max_fee_per_blob_gas, _tx), do: :blob_base_fee
  defp fill_action(:gas_price, _tx), do: :gas_price
  defp fill_action(:gas, tx), do: {:estimate_gas, tx}

  defp post_process([], [], acc), do: {:ok, Map.new(acc)}

  defp post_process([k | tk], [v | tv], acc) do
    with {:ok, item} <- do_post_process(k, v) do
      post_process(tk, tv, [item | acc])
    end
  end

  defp do_post_process(field, {:ok, value})
       when field in [:max_fee_per_gas, :max_fee_per_blob_gas] do
    # Setting a higher value for max_fee_per and max_fee_per_blob_gas gas since the actual base
    # fee is determined by the last block. This way we minimize the chance to get stuck in
    # queue when base fee increases.
    {:ok, {field, max_fee_per_gas_with_margin(value)}}
  end

  defp do_post_process(:gas, {:ok, gas}) do
    {:ok, {:gas, gas_with_margin(gas)}}
  end

  defp do_post_process(key, {:ok, v_int}) when is_integer(v_int) do
    {:ok, {key, v_int}}
  end

  defp do_post_process(_key, {:error, reason}), do: {:error, reason}

  defp decode_type(nil), do: {:ok, Legacy}

  defp decode_type("0x" <> _ = type) do
    case Utils.hex_to_integer(type) do
      {:ok, type_id} -> type_module(type_id)
      {:error, :invalid_hex} -> {:error, :invalid_type}
    end
  end

  defp decode_type(_type), do: {:error, :invalid_type}

  Enum.each(@transaction_types, fn module ->
    type_id = module.type_id()
    defp type_module(unquote(type_id)), do: {:ok, unquote(module)}
  end)

  defp type_module(type_id), do: {:ok, Unknown, type_id}

  defp from_map_value_bin(tx, key) do
    case from_map_value(tx, key) do
      nil -> nil
      hex -> Utils.hex_decode!(hex)
    end
  end

  defp from_map_value_int(tx, key) do
    case from_map_value(tx, key) do
      nil -> nil
      hex -> Utils.hex_to_integer!(hex)
    end
  end

  defp from_map_value(tx, key) do
    Map.get_lazy(tx, key, fn -> Map.get(tx, to_string(key)) end)
  end

  defp from_rpc_access_list(nil), do: nil

  defp from_rpc_access_list(access_list) when is_list(access_list) do
    Enum.map(access_list, fn entry ->
      storage_keys = from_map_value(entry, :storageKeys) || []

      [
        entry |> from_map_value(:address) |> Utils.decode_address!(),
        Enum.map(storage_keys, &Utils.hex_decode!/1)
      ]
    end)
  end

  defp from_rpc_blob_versioned_hashes(nil), do: nil

  defp from_rpc_blob_versioned_hashes(hashes) when is_list(hashes),
    do: Enum.map(hashes, &Utils.hex_decode!/1)

  defp from_rpc_authorization_list(nil), do: nil

  defp from_rpc_authorization_list(authorization_list) when is_list(authorization_list) do
    Enum.map(authorization_list, fn authorization ->
      %Authorization.Signed{
        authorization: %Authorization{
          chain_id: from_map_value_int(authorization, :chainId),
          address: authorization |> from_map_value(:address) |> Utils.maybe_checksum_address(),
          nonce: from_map_value_int(authorization, :nonce)
        },
        signature_y_parity: from_map_value_int(authorization, :yParity),
        signature_r: from_map_value_bin(authorization, :r),
        signature_s: from_map_value_bin(authorization, :s)
      }
    end)
  end

  @doc false
  def default_transaction_type, do: @default_transaction_type

  defp gas_with_margin(value) do
    margin = Application.get_env(:ethers, :default_gas_margin, 11_000)
    with_margin(value, margin)
  end

  defp max_fee_per_gas_with_margin(value) do
    margin = Application.get_env(:ethers, :default_max_fee_per_gas_margin, 12_000)
    with_margin(value, margin)
  end

  defp with_margin(value, margin) do
    div(value * margin, @margin_precision)
  end
end
