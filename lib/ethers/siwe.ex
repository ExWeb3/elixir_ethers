defmodule Ethers.Siwe do
  @moduledoc """
  Sign-In with Ethereum ([EIP-4361](https://eips.ethereum.org/EIPS/eip-4361)) messages.

  SIWE is the standard way for a wallet to authenticate to an off-chain service: the backend
  issues a nonce, the wallet signs a structured plaintext message containing it, and the
  backend parses, validates and verifies the returned message and signature.

  This module covers the message lifecycle:

  - `new/1` / `new!/1` - build an `Ethers.Siwe.Message`
  - `generate_nonce/0` - generate a cryptographically random nonce
  - `to_message/1` - render the EIP-4361 string for the wallet to sign
  - `parse/1` - parse a message string received from a client
  - `validate/2` - stateless validation (validity window, domain/nonce/address binding)

  See the [Sign-In with Ethereum guide](siwe.html) for a complete Phoenix integration recipe.

  ## Example

      iex> {:ok, message} =
      ...>   Ethers.Siwe.new(
      ...>     domain: "example.com",
      ...>     address: "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2",
      ...>     statement: "Sign in to Example",
      ...>     uri: "https://example.com/login",
      ...>     chain_id: 1,
      ...>     nonce: "32891756",
      ...>     issued_at: "2021-09-30T16:25:24.000Z"
      ...>   )
      iex> Ethers.Siwe.to_message(message)
      "example.com wants you to sign in with your Ethereum account:\\n0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2\\n\\nSign in to Example\\n\\nURI: https://example.com/login\\nVersion: 1\\nChain ID: 1\\nNonce: 32891756\\nIssued At: 2021-09-30T16:25:24.000Z"
  """

  alias Ethers.Siwe.Message
  alias Ethers.Utils

  @preamble " wants you to sign in with your Ethereum account:"

  # RFC 3986 character classes used to validate the `domain` (authority), `scheme` and
  # `request_id` fields.
  @unreserved_or_sub_delims "A-Za-z0-9\\-._~!$&'()*+,;="
  @pct_encoded "%[0-9A-Fa-f]{2}"
  @userinfo "(?:[#{@unreserved_or_sub_delims}:]|#{@pct_encoded})*"
  @reg_name "(?:[#{@unreserved_or_sub_delims}]|#{@pct_encoded})+"
  @ip_literal "\\[(?:[0-9A-Fa-f:.]+|v[0-9A-Fa-f]+\\.[#{@unreserved_or_sub_delims}:]+)\\]"

  @authority_regex ~r/^(?:#{@userinfo}@)?(?:#{@ip_literal}|#{@reg_name})(?::[0-9]*)?$/
  @scheme_regex ~r/^[A-Za-z][A-Za-z0-9+\-.]*$/
  @nonce_regex ~r/^[a-zA-Z0-9]{8,}$/
  @request_id_regex ~r/^(?:[#{@unreserved_or_sub_delims}:@]|#{@pct_encoded})*$/
  @pct_encoding_regex ~r/^(?:[^%]|%[0-9A-Fa-f]{2})*$/
  @rfc3339_regex ~r/^\d{4}-\d{2}-\d{2}[Tt]\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:[Zz]|[+-]\d{2}:\d{2})$/

  @doc """
  Builds a new `Ethers.Siwe.Message` from a keyword list or map.

  Accepts atom keys (`:chain_id`) or string keys (`"chain_id"`). Required fields are
  `:domain`, `:address`, `:uri`, `:chain_id` and `:nonce`. `:version` defaults to `"1"`
  (the only defined version) and `:issued_at` defaults to the current UTC time.

  The address is normalized to its EIP-55 checksummed form. Timestamp fields accept either
  `DateTime` structs or RFC 3339 strings (kept verbatim).

  Returns `{:error, reason}` with a descriptive atom (e.g. `:missing_domain`,
  `:invalid_nonce`) when a field is missing or invalid.

  ## Examples

      iex> {:ok, message} =
      ...>   Ethers.Siwe.new(
      ...>     domain: "example.com",
      ...>     address: "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2",
      ...>     uri: "https://example.com",
      ...>     chain_id: 1,
      ...>     nonce: Ethers.Siwe.generate_nonce()
      ...>   )
      iex> message.address
      "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"
      iex> message.version
      "1"

      iex> Ethers.Siwe.new(domain: "example.com")
      {:error, :missing_address}
  """
  @spec new(Keyword.t() | map()) :: {:ok, Message.t()} | {:error, atom()}
  def new(params) when is_list(params), do: params |> Map.new() |> new()

  def new(params) when is_map(params) do
    with {:ok, scheme} <- validate_scheme(fetch(params, :scheme)),
         {:ok, domain} <- validate_domain(fetch(params, :domain)),
         {:ok, address} <- normalize_address(fetch(params, :address)),
         {:ok, statement} <- validate_statement(fetch(params, :statement)),
         {:ok, uri} <- validate_uri(fetch(params, :uri)),
         {:ok, version} <- validate_version(fetch(params, :version) || "1"),
         {:ok, chain_id} <- validate_chain_id(fetch(params, :chain_id)),
         {:ok, nonce} <- validate_nonce(fetch(params, :nonce)),
         {:ok, issued_at} <-
           validate_timestamp(fetch(params, :issued_at) || DateTime.utc_now(), :invalid_issued_at),
         {:ok, expiration_time} <-
           validate_timestamp(fetch(params, :expiration_time), :invalid_expiration_time),
         {:ok, not_before} <- validate_timestamp(fetch(params, :not_before), :invalid_not_before),
         {:ok, request_id} <- validate_request_id(fetch(params, :request_id)),
         {:ok, resources} <- validate_resources(fetch(params, :resources)) do
      {:ok,
       %Message{
         scheme: scheme,
         domain: domain,
         address: address,
         statement: statement,
         uri: uri,
         version: version,
         chain_id: chain_id,
         nonce: nonce,
         issued_at: issued_at,
         expiration_time: expiration_time,
         not_before: not_before,
         request_id: request_id,
         resources: resources
       }}
    end
  end

  @doc """
  Same as `new/1` but raises `ArgumentError` on error.
  """
  @spec new!(Keyword.t() | map()) :: Message.t() | no_return()
  def new!(params) do
    case new(params) do
      {:ok, message} -> message
      {:error, reason} -> raise ArgumentError, "could not build SIWE message: #{inspect(reason)}"
    end
  end

  @doc """
  Generates a cryptographically random alphanumeric nonce with at least 8 characters.

  Uses 128 bits of entropy from `:crypto.strong_rand_bytes/1` encoded in base 36.
  """
  @spec generate_nonce() :: String.t()
  def generate_nonce do
    :crypto.strong_rand_bytes(16)
    |> :binary.decode_unsigned()
    |> Integer.to_string(36)
    |> String.pad_leading(8, "0")
  end

  @doc """
  Renders the message as the EIP-4361 string the wallet will sign.

  The `String.Chars` protocol is also implemented for `Ethers.Siwe.Message`, so
  `to_string/1` and string interpolation work as well.
  """
  @spec to_message(Message.t()) :: String.t()
  def to_message(%Message{} = message) do
    header = "#{scheme_prefix(message.scheme)}#{message.domain}#{@preamble}"

    lines =
      [header, message.address, ""] ++
        statement_lines(message.statement) ++
        [""] ++
        required_field_lines(message) ++
        optional_field_lines(message) ++
        resource_lines(message.resources)

    Enum.join(lines, "\n")
  end

  @doc """
  Parses an EIP-4361 message string into an `Ethers.Siwe.Message`.

  Parsing is strict: field order, the EIP-55 checksummed address, the nonce format, RFC 3339
  timestamps and RFC 3986 domain/URIs are all enforced. A successfully parsed message
  re-renders byte-for-byte identical via `to_message/1`.

  ## Examples

      iex> raw =
      ...>   "example.com wants you to sign in with your Ethereum account:\\n" <>
      ...>     "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2\\n\\n\\n" <>
      ...>     "URI: https://example.com\\nVersion: 1\\nChain ID: 1\\n" <>
      ...>     "Nonce: 32891756\\nIssued At: 2021-09-30T16:25:24.000Z"
      iex> {:ok, message} = Ethers.Siwe.parse(raw)
      iex> {message.domain, message.chain_id, message.statement}
      {"example.com", 1, nil}
  """
  @spec parse(String.t()) :: {:ok, Message.t()} | {:error, atom()}
  def parse(message) when is_binary(message) do
    lines = String.split(message, "\n")

    with {:ok, {raw_scheme, raw_domain}, lines} <- parse_header(lines),
         {:ok, raw_address, lines} <- pop_line(lines),
         {:ok, raw_statement, lines} <- parse_statement(lines),
         {:ok, fields, lines} <- parse_fields(lines),
         :ok <- ensure_consumed(lines),
         {:ok, scheme} <- validate_scheme(raw_scheme),
         {:ok, domain} <- validate_domain(raw_domain),
         {:ok, address} <- validate_checksummed_address(raw_address),
         {:ok, statement} <- validate_statement(raw_statement),
         {:ok, uri} <- validate_uri(fields.uri),
         {:ok, version} <- validate_version(fields.version),
         {:ok, chain_id} <- parse_chain_id(fields.chain_id),
         {:ok, nonce} <- validate_nonce(fields.nonce),
         {:ok, issued_at} <- validate_timestamp(fields.issued_at, :invalid_issued_at),
         {:ok, expiration_time} <-
           validate_timestamp(fields.expiration_time, :invalid_expiration_time),
         {:ok, not_before} <- validate_timestamp(fields.not_before, :invalid_not_before),
         {:ok, request_id} <- validate_request_id(fields.request_id),
         {:ok, resources} <- validate_resources(fields.resources) do
      {:ok,
       %Message{
         scheme: scheme,
         domain: domain,
         address: address,
         statement: statement,
         uri: uri,
         version: version,
         chain_id: chain_id,
         nonce: nonce,
         issued_at: issued_at,
         expiration_time: expiration_time,
         not_before: not_before,
         request_id: request_id,
         resources: resources
       }}
    end
  end

  @doc """
  Statelessly validates a message against the current time and the expected binding values.

  This performs no signature verification and no RPC requests - it only checks the message
  fields themselves.

  ## Options

  - `:time` - the `DateTime` to check the validity window against. Defaults to
    `DateTime.utc_now/0`. The message is invalid at and after `expiration_time` (exclusive
    upper bound) and before `not_before` (inclusive lower bound).
  - `:domain` - the domain this backend expects (exact match).
  - `:scheme` - the scheme this backend expects (exact match).
  - `:nonce` - the nonce this backend issued for the session (exact match).
  - `:address` - the expected signing address (case-insensitive comparison).

  Omitted options are not checked.

  Returns `:ok` or `{:error, reason}` where reason is one of `:invalid_version`, `:expired`,
  `:not_yet_valid`, `:invalid_expiration_time`, `:invalid_not_before`, `:domain_mismatch`,
  `:scheme_mismatch`, `:nonce_mismatch`, `:address_mismatch` or `:invalid_address`.
  """
  @spec validate(Message.t(), Keyword.t()) :: :ok | {:error, atom()}
  def validate(%Message{} = message, opts \\ []) do
    time = Keyword.get(opts, :time) || DateTime.utc_now()

    with :ok <- check_version(message),
         :ok <- check_expiration_time(message, time),
         :ok <- check_not_before(message, time),
         :ok <- check_exact(message.domain, Keyword.get(opts, :domain), :domain_mismatch),
         :ok <- check_exact(message.scheme, Keyword.get(opts, :scheme), :scheme_mismatch),
         :ok <- check_exact(message.nonce, Keyword.get(opts, :nonce), :nonce_mismatch) do
      check_address(message, Keyword.get(opts, :address))
    end
  end

  ## Message rendering helpers

  defp scheme_prefix(nil), do: ""
  defp scheme_prefix(scheme), do: "#{scheme}://"

  defp statement_lines(nil), do: []
  defp statement_lines(statement), do: [statement]

  defp required_field_lines(%Message{} = message) do
    [
      "URI: #{message.uri}",
      "Version: #{message.version}",
      "Chain ID: #{message.chain_id}",
      "Nonce: #{message.nonce}",
      "Issued At: #{message.issued_at}"
    ]
  end

  defp optional_field_lines(%Message{} = message) do
    for {label, value} <- [
          {"Expiration Time", message.expiration_time},
          {"Not Before", message.not_before},
          {"Request ID", message.request_id}
        ],
        not is_nil(value) do
      "#{label}: #{value}"
    end
  end

  defp resource_lines([]), do: []
  defp resource_lines(resources), do: ["Resources:" | Enum.map(resources, &("- " <> &1))]

  ## Parsing helpers

  defp parse_header([line | rest]) do
    if String.ends_with?(line, @preamble) do
      line
      |> binary_part(0, byte_size(line) - byte_size(@preamble))
      |> split_scheme()
      |> then(&{:ok, &1, rest})
    else
      {:error, :invalid_message_format}
    end
  end

  defp split_scheme(authority) do
    case String.split(authority, "://", parts: 2) do
      [domain] -> {nil, domain}
      [scheme, domain] -> {scheme, domain}
    end
  end

  defp pop_line([line | rest]), do: {:ok, line, rest}
  defp pop_line([]), do: {:error, :invalid_message_format}

  defp parse_statement(["", "" | rest]), do: {:ok, nil, rest}

  defp parse_statement(["", statement, "" | rest]) when statement != "",
    do: {:ok, statement, rest}

  defp parse_statement(_lines), do: {:error, :invalid_message_format}

  defp parse_fields(lines) do
    with {:ok, uri, rest} <- take_required(lines, "URI: "),
         {:ok, version, rest} <- take_required(rest, "Version: "),
         {:ok, chain_id, rest} <- take_required(rest, "Chain ID: "),
         {:ok, nonce, rest} <- take_required(rest, "Nonce: "),
         {:ok, issued_at, rest} <- take_required(rest, "Issued At: ") do
      {expiration_time, rest} = take_optional(rest, "Expiration Time: ")
      {not_before, rest} = take_optional(rest, "Not Before: ")
      {request_id, rest} = take_optional(rest, "Request ID: ")
      {resources, rest} = take_resources(rest)

      fields = %{
        uri: uri,
        version: version,
        chain_id: chain_id,
        nonce: nonce,
        issued_at: issued_at,
        expiration_time: expiration_time,
        not_before: not_before,
        request_id: request_id,
        resources: resources
      }

      {:ok, fields, rest}
    end
  end

  defp take_required([line | rest], prefix) do
    if String.starts_with?(line, prefix) do
      {:ok, String.replace_prefix(line, prefix, ""), rest}
    else
      {:error, :invalid_message_format}
    end
  end

  defp take_required([], _prefix), do: {:error, :invalid_message_format}

  defp take_optional([line | rest] = lines, prefix) do
    if String.starts_with?(line, prefix) do
      {String.replace_prefix(line, prefix, ""), rest}
    else
      {nil, lines}
    end
  end

  defp take_optional([], _prefix), do: {nil, []}

  defp take_resources(["Resources:" | rest]) do
    {resource_lines, rest} = Enum.split_while(rest, &String.starts_with?(&1, "- "))
    {Enum.map(resource_lines, &String.replace_prefix(&1, "- ", "")), rest}
  end

  defp take_resources(lines), do: {nil, lines}

  defp ensure_consumed([]), do: :ok
  defp ensure_consumed(_lines), do: {:error, :invalid_message_format}

  ## Field validation helpers (shared between new/1 and parse/1)

  defp validate_scheme(nil), do: {:ok, nil}

  defp validate_scheme(scheme) when is_binary(scheme) do
    if Regex.match?(@scheme_regex, scheme), do: {:ok, scheme}, else: {:error, :invalid_scheme}
  end

  defp validate_scheme(_scheme), do: {:error, :invalid_scheme}

  defp validate_domain(nil), do: {:error, :missing_domain}

  defp validate_domain(domain) when is_binary(domain) do
    if Regex.match?(@authority_regex, domain), do: {:ok, domain}, else: {:error, :invalid_domain}
  end

  defp validate_domain(_domain), do: {:error, :invalid_domain}

  defp normalize_address(nil), do: {:error, :missing_address}

  defp normalize_address(<<prefix::binary-2, hex::binary-40>>) when prefix in ["0x", "0X"] do
    case Utils.hex_decode(hex) do
      {:ok, _address_bin} -> {:ok, Utils.to_checksum_address("0x" <> hex)}
      :error -> {:error, :invalid_address}
    end
  end

  defp normalize_address(_address), do: {:error, :invalid_address}

  defp validate_checksummed_address(address) do
    case normalize_address(address) do
      {:ok, ^address} -> {:ok, address}
      {:ok, _other} -> {:error, :invalid_address}
      {:error, reason} -> {:error, reason}
    end
  end

  defp validate_statement(nil), do: {:ok, nil}

  defp validate_statement(statement) when is_binary(statement) do
    if String.contains?(statement, ["\n", "\r"]) do
      {:error, :invalid_statement}
    else
      {:ok, statement}
    end
  end

  defp validate_statement(_statement), do: {:error, :invalid_statement}

  defp validate_uri(nil), do: {:error, :missing_uri}

  defp validate_uri(uri) do
    if valid_uri?(uri), do: {:ok, uri}, else: {:error, :invalid_uri}
  end

  defp valid_uri?(uri) when is_binary(uri) do
    case URI.new(uri) do
      {:ok, %URI{scheme: scheme}} when is_binary(scheme) -> Regex.match?(@pct_encoding_regex, uri)
      _other -> false
    end
  end

  defp valid_uri?(_uri), do: false

  defp validate_version("1"), do: {:ok, "1"}
  defp validate_version(_version), do: {:error, :invalid_version}

  defp validate_chain_id(nil), do: {:error, :missing_chain_id}

  defp validate_chain_id(chain_id) when is_integer(chain_id) and chain_id >= 0,
    do: {:ok, chain_id}

  defp validate_chain_id(_chain_id), do: {:error, :invalid_chain_id}

  defp parse_chain_id(chain_id) do
    if Regex.match?(~r/^[0-9]+$/, chain_id) do
      {:ok, String.to_integer(chain_id)}
    else
      {:error, :invalid_chain_id}
    end
  end

  defp validate_nonce(nil), do: {:error, :missing_nonce}

  defp validate_nonce(nonce) when is_binary(nonce) do
    if Regex.match?(@nonce_regex, nonce), do: {:ok, nonce}, else: {:error, :invalid_nonce}
  end

  defp validate_nonce(_nonce), do: {:error, :invalid_nonce}

  defp validate_timestamp(nil, _error), do: {:ok, nil}

  defp validate_timestamp(%DateTime{} = timestamp, _error),
    do: {:ok, DateTime.to_iso8601(timestamp)}

  defp validate_timestamp(timestamp, error) when is_binary(timestamp) do
    with true <- Regex.match?(@rfc3339_regex, timestamp),
         {:ok, _datetime, _offset} <- DateTime.from_iso8601(timestamp) do
      {:ok, timestamp}
    else
      _other -> {:error, error}
    end
  end

  defp validate_timestamp(_timestamp, error), do: {:error, error}

  defp validate_request_id(nil), do: {:ok, nil}

  defp validate_request_id(request_id) when is_binary(request_id) do
    if Regex.match?(@request_id_regex, request_id) do
      {:ok, request_id}
    else
      {:error, :invalid_request_id}
    end
  end

  defp validate_request_id(_request_id), do: {:error, :invalid_request_id}

  defp validate_resources(nil), do: {:ok, []}

  defp validate_resources(resources) when is_list(resources) do
    if Enum.all?(resources, &valid_uri?/1) do
      {:ok, resources}
    else
      {:error, :invalid_resources}
    end
  end

  defp validate_resources(_resources), do: {:error, :invalid_resources}

  ## Validation (validate/2) helpers

  defp check_version(%Message{version: "1"}), do: :ok
  defp check_version(%Message{}), do: {:error, :invalid_version}

  defp check_expiration_time(%Message{expiration_time: nil}, _time), do: :ok

  defp check_expiration_time(%Message{expiration_time: expiration_time}, time) do
    case DateTime.from_iso8601(expiration_time) do
      {:ok, expiration, _offset} ->
        if DateTime.compare(time, expiration) == :lt, do: :ok, else: {:error, :expired}

      {:error, _reason} ->
        {:error, :invalid_expiration_time}
    end
  end

  defp check_not_before(%Message{not_before: nil}, _time), do: :ok

  defp check_not_before(%Message{not_before: not_before}, time) do
    case DateTime.from_iso8601(not_before) do
      {:ok, not_before_time, _offset} ->
        if DateTime.compare(time, not_before_time) == :lt do
          {:error, :not_yet_valid}
        else
          :ok
        end

      {:error, _reason} ->
        {:error, :invalid_not_before}
    end
  end

  defp check_exact(_actual, nil, _error), do: :ok
  defp check_exact(actual, expected, _error) when actual == expected, do: :ok
  defp check_exact(_actual, _expected, error), do: {:error, error}

  defp check_address(%Message{}, nil), do: :ok

  defp check_address(%Message{address: address}, expected) do
    with {:ok, expected_bin} <- decode_address(expected),
         {:ok, address_bin} <- decode_address(address) do
      if expected_bin == address_bin, do: :ok, else: {:error, :address_mismatch}
    end
  end

  defp decode_address(<<prefix::binary-2, hex::binary-40>>) when prefix in ["0x", "0X"] do
    case Utils.hex_decode(hex) do
      {:ok, address_bin} -> {:ok, address_bin}
      :error -> {:error, :invalid_address}
    end
  end

  defp decode_address(_address), do: {:error, :invalid_address}

  defp fetch(params, key) do
    case Map.fetch(params, key) do
      {:ok, value} -> value
      :error -> Map.get(params, Atom.to_string(key))
    end
  end
end
