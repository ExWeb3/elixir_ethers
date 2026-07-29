defmodule Ethers.StateOverride do
  @moduledoc """
  State overrides for simulation RPC calls (`eth_call` and `eth_estimateGas`).

  State overrides let a call run against a modified view of the chain state without
  sending any transaction: spoof an account's balance or nonce, replace the code at an
  address (e.g. run a contract that is not deployed), or rewrite individual storage
  slots. They are supported by all major execution clients (geth, reth, anvil, ...).

  Pass them to `Ethers.call/2`, `Ethers.estimate_gas/2` (and by extension any generated
  contract function piped into those) with the `:state_overrides` option:

  ```elixir
  MyToken.transfer(receiver, 1000)
  |> Ethers.call(
    from: whale,
    state_overrides: %{
      whale => %{balance: Ethers.Utils.to_wei(100)},
      token_address => %{state_diff: %{balance_slot => balance_value}}
    }
  )
  ```

  ## Structure

  A state override set is a map of `address => account override`. Following Ethers
  conventions, every value has exactly one accepted representation — native types, never
  hex strings:

  - `:balance` - fake balance to set for the account (`non_neg_integer`)
  - `:nonce` - fake nonce to set for the account (`non_neg_integer`)
  - `:code` - fake EVM bytecode to inject into the account (raw `binary`, **not** hex
    encoded — hex decode first if you have `"0x..."` bytecode e.g. from `eth_getCode`)
  - `:state` - fake key-value mapping to override **all** slots in the account storage
  - `:state_diff` - fake key-value mapping to override **individual** slots in the
    account storage (all other slots keep their on-chain values)

  `:state` and `:state_diff` are mutually exclusive per account. Their keys (storage
  slots) and values (storage words) accept a `non_neg_integer` or a raw 32-byte binary
  (e.g. a keccak-derived mapping slot), and are encoded as 32-byte hex words.

  Addresses are hex strings (`"0x..."`), like everywhere else in Ethers.
  """

  alias Ethers.Types
  alias Ethers.Utils

  @typedoc """
  A storage slot or storage value: a non-negative integer or a raw 32-byte binary.
  """
  @type storage_word :: non_neg_integer() | <<_::256>>

  @typedoc """
  Overrides for a single account. See the module documentation for the accepted keys.
  """
  @type account_override :: %{
          optional(:balance) => non_neg_integer(),
          optional(:nonce) => non_neg_integer(),
          optional(:code) => binary(),
          optional(:state) => %{storage_word() => storage_word()},
          optional(:state_diff) => %{storage_word() => storage_word()}
        }

  @typedoc "A state override set: a map of account address to account override."
  @type t :: %{Types.t_address() => account_override()}

  @doc """
  Encodes a state override set into the JSON-RPC representation.

  Returns `{:ok, rpc_map}` with all quantities, code and storage words hex-encoded,
  or `{:error, reason}` if the input is not a valid state override set.

  ## Examples

      iex> Ethers.StateOverride.to_rpc_map(%{
      ...>   "0x90F8bf6A479f320ead074411a4B0e7944Ea8c9C1" => %{balance: 1000, nonce: 3}
      ...> })
      {:ok, %{"0x90F8bf6A479f320ead074411a4B0e7944Ea8c9C1" => %{balance: "0x3E8", nonce: "0x3"}}}
  """
  @spec to_rpc_map(t()) :: {:ok, map()} | {:error, term()}
  def to_rpc_map(state_overrides) when is_map(state_overrides) do
    Enum.reduce_while(state_overrides, {:ok, %{}}, fn {address, account_override}, {:ok, acc} ->
      with {:ok, address} <- validate_address(address),
           {:ok, account_override} <- encode_account_override(account_override) do
        {:cont, {:ok, Map.put(acc, address, account_override)}}
      else
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  def to_rpc_map(_state_overrides), do: {:error, :invalid_state_overrides}

  defp validate_address(address) do
    case Utils.decode_address(address) do
      {:ok, _bin} -> {:ok, address}
      {:error, reason} -> {:error, {reason, address}}
    end
  end

  defp encode_account_override(account_override) when is_map(account_override) do
    if Map.has_key?(account_override, :state) and Map.has_key?(account_override, :state_diff) do
      {:error, :state_and_state_diff_exclusive}
    else
      encode_account_override_values(account_override)
    end
  end

  defp encode_account_override(account_override),
    do: {:error, {:invalid_account_override, account_override}}

  defp encode_account_override_values(account_override) do
    Enum.reduce_while(account_override, {:ok, %{}}, fn {key, value}, {:ok, acc} ->
      case encode_account_override_value(key, value) do
        {:ok, key, value} -> {:cont, {:ok, Map.put(acc, key, value)}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp encode_account_override_value(key, quantity)
       when key in [:balance, :nonce] and is_integer(quantity) and quantity >= 0,
       do: {:ok, key, Utils.integer_to_hex(quantity)}

  defp encode_account_override_value(:code, code) when is_binary(code),
    do: {:ok, :code, Utils.hex_encode(code)}

  defp encode_account_override_value(key, storage_map)
       when key in [:state, :state_diff] and is_map(storage_map) do
    rpc_key = if key == :state, do: :state, else: :stateDiff

    Enum.reduce_while(storage_map, {:ok, %{}}, fn {slot, value}, {:ok, acc} ->
      with {:ok, slot} <- encode_storage_word(slot),
           {:ok, value} <- encode_storage_word(value) do
        {:cont, {:ok, Map.put(acc, slot, value)}}
      else
        {:error, reason} -> {:halt, {:error, {:invalid_account_override, {key, reason}}}}
      end
    end)
    |> case do
      {:ok, encoded} -> {:ok, rpc_key, encoded}
      {:error, reason} -> {:error, reason}
    end
  end

  defp encode_account_override_value(key, value),
    do: {:error, {:invalid_account_override, {key, value}}}

  @max_word 2 ** 256 - 1

  defp encode_storage_word(word) when is_integer(word) and word >= 0 and word <= @max_word,
    do: {:ok, Utils.hex_encode(<<word::256>>)}

  defp encode_storage_word(<<_::binary-32>> = word), do: {:ok, Utils.hex_encode(word)}

  defp encode_storage_word(word), do: {:error, {:invalid_storage_word, word}}
end
