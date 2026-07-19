defmodule Ethers.Siwe.Message do
  @moduledoc """
  A Sign-In with Ethereum ([EIP-4361](https://eips.ethereum.org/EIPS/eip-4361)) message.

  Use `Ethers.Siwe.new/1` to build a message, `Ethers.Siwe.parse/1` to parse one from its
  string form and `Ethers.Siwe.to_message/1` (or `to_string/1`) to render it.

  Timestamps (`issued_at`, `expiration_time` and `not_before`) are stored as RFC 3339 strings
  exactly as they appear in the message. This guarantees that a parsed message re-renders
  byte-for-byte identical to its source - which is required for signature verification - even
  for timestamps with non-UTC offsets or unusual sub-second precision. `Ethers.Siwe.new/1`
  accepts `DateTime` values and converts them for you; `Ethers.Siwe.validate/2` parses them
  back when checking the validity window.
  """

  defstruct [
    :scheme,
    :domain,
    :address,
    :statement,
    :uri,
    :version,
    :chain_id,
    :nonce,
    :issued_at,
    :expiration_time,
    :not_before,
    :request_id,
    resources: []
  ]

  @typedoc """
  An EIP-4361 message.

  - `scheme` - optional URI scheme of the origin of the request (e.g. `"https"`).
  - `domain` - the RFC 3986 authority requesting the signing (e.g. `"example.com"`).
  - `address` - the EIP-55 checksummed Ethereum address performing the signing.
  - `statement` - optional human-readable assertion to sign (must not contain newlines).
  - `uri` - RFC 3986 URI referring to the resource that is the subject of the signing.
  - `version` - current version of the SIWE message, always `"1"`.
  - `chain_id` - the EIP-155 chain id to which the session is bound.
  - `nonce` - randomized token (at least 8 alphanumeric characters), see
    `Ethers.Siwe.generate_nonce/0`.
  - `issued_at` - RFC 3339 timestamp of when the message was generated.
  - `expiration_time` - optional RFC 3339 timestamp at (and after) which the message is
    considered expired.
  - `not_before` - optional RFC 3339 timestamp before which the message is not yet valid.
  - `request_id` - optional system-specific request identifier.
  - `resources` - list of RFC 3986 URIs the user wishes to have resolved as part of
    authentication.
  """
  @type t :: %__MODULE__{
          scheme: String.t() | nil,
          domain: String.t(),
          address: Ethers.Types.t_address(),
          statement: String.t() | nil,
          uri: String.t(),
          version: String.t(),
          chain_id: non_neg_integer(),
          nonce: String.t(),
          issued_at: String.t(),
          expiration_time: String.t() | nil,
          not_before: String.t() | nil,
          request_id: String.t() | nil,
          resources: [String.t()]
        }

  defimpl String.Chars do
    def to_string(message), do: Ethers.Siwe.to_message(message)
  end
end
