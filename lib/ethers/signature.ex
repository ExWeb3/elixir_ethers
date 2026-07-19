defmodule Ethers.Signature do
  @moduledoc """
  Universal signature verification: EOA (`ecrecover`), smart-contract wallets
  ([ERC-1271](https://eips.ethereum.org/EIPS/eip-1271)) and counterfactual —
  not-yet-deployed — wallets ([ERC-6492](https://eips.ethereum.org/EIPS/eip-6492)).

  Smart-contract wallets (Safe, Coinbase Smart Wallet, ERC-4337/EIP-7702 accounts, ...)
  cannot produce signatures that `ecrecover` validates. Backends which only use
  `ecrecover`-based verification (`Ethers.PersonalMessage.verify/3`,
  `Ethers.TypedData.valid_signature?/3`) silently reject all smart-wallet users. The
  functions in this module verify *any* signature:

  1. **Fast path** — for plain 65-byte ECDSA signatures, `ecrecover` runs locally first.
     A match verifies without any RPC round-trip.
  2. **Universal path** — otherwise, one `eth_call` executes the
     `Ethers.Contracts.UniversalSigValidator` contract *deploylessly* (no `to` address,
     nothing gets deployed on chain). The validator unwraps ERC-6492 signatures
     (counterfactually deploying the wallet inside the call), performs the ERC-1271
     `isValidSignature/2` check for contract accounts, and falls back to `ecrecover`.

  Verification outcome is a boolean inside an ok-tuple: `{:ok, false}` means the
  signature is *invalid*, while `{:error, reason}` is reserved for transport/RPC
  failures. There are deliberately no bang variants — raising would conflate an invalid
  signature with an RPC failure.

  ## Example

  A backend verifying a wallet login message:

  ```elixir
  {:ok, true} = Ethers.Signature.verify_message("Sign in to Example", signature, address)

  # With explicit RPC options
  Ethers.Signature.verify_message("Sign in to Example", signature, address,
    rpc_opts: [url: "https://eth.example.com"]
  )
  ```
  """

  import Ethers.RpcClient, only: [get_rpc_client: 1]

  alias Ethers.Contracts.UniversalSigValidator
  alias Ethers.Types
  alias Ethers.Utils

  @doc """
  Verifies a signature over a 32-byte digest against an address.

  Accepts any signature kind: plain 65-byte ECDSA (EOA), ERC-1271 (verified on-chain
  via the account contract) and ERC-6492-wrapped (counterfactual wallets). Plain EOA
  signatures that recover to `address` are verified locally without any RPC call.

  ## Parameters

  - `hash`: The 32-byte digest that was signed — either a raw binary or a `0x`-prefixed
    hex string. (e.g. `Ethers.PersonalMessage.hash/1` or `Ethers.TypedData.hash/1`)
  - `signature`: The signature as a `0x`-prefixed hex string or raw binary.
    ERC-6492-wrapped signatures (longer than 65 bytes) are passed to the validator
    untouched.
  - `address`: The address to verify against (EOA or smart-contract account).
  - `opts`: Options.

  ## Options

  - `:block`: The block number (integer) or block tag for the validation `eth_call`.
    Defaults to `"latest"`.
  - `:rpc_client`: The RPC Client to use. It should implement ethereum jsonRPC API.
    default: Ethereumex.HttpClient
  - `:rpc_opts`: Extra options to pass to rpc_client. (Like timeout, Server URL, etc.)

  ## Returns

  - `{:ok, true}` if the signature is valid for `address`.
  - `{:ok, false}` if the signature is invalid.
  - `{:error, reason}` on malformed input or RPC transport failure.
  """
  @spec verify_hash(binary(), binary(), Types.t_address(), Keyword.t()) ::
          {:ok, boolean()} | {:error, term()}
  def verify_hash(hash, signature, address, opts \\ []) do
    with {:ok, hash} <- normalize_hash(hash),
         {:ok, signature} <- normalize_signature(signature),
         {:ok, address_bin} <- normalize_address(address) do
      if ecrecover_match?(hash, signature, address_bin) do
        {:ok, true}
      else
        validate_on_chain(hash, signature, address_bin, opts)
      end
    end
  end

  @doc """
  Verifies a signature over an [EIP-191](https://eips.ethereum.org/EIPS/eip-191)
  personal message (the `personal_sign` scheme) against an address.

  Hashes `message` with `Ethers.PersonalMessage.hash/1` and delegates to
  `verify_hash/4` — see it for accepted signature kinds, options and return values.
  """
  @spec verify_message(binary(), binary(), Types.t_address(), Keyword.t()) ::
          {:ok, boolean()} | {:error, term()}
  def verify_message(message, signature, address, opts \\ []) when is_binary(message) do
    verify_hash(Ethers.PersonalMessage.hash(message), signature, address, opts)
  end

  @doc """
  Verifies a signature over [EIP-712](https://eips.ethereum.org/EIPS/eip-712) typed
  structured data against an address.

  Hashes `typed_data` with `Ethers.TypedData.hash/1` and delegates to `verify_hash/4` —
  see it for accepted signature kinds, options and return values.
  """
  @spec verify_typed_data(Ethers.TypedData.t(), binary(), Types.t_address(), Keyword.t()) ::
          {:ok, boolean()} | {:error, term()}
  def verify_typed_data(%Ethers.TypedData{} = typed_data, signature, address, opts \\ []) do
    verify_hash(Ethers.TypedData.hash(typed_data), signature, address, opts)
  end

  defp normalize_hash(<<_::binary-size(32)>> = hash), do: {:ok, hash}

  defp normalize_hash(<<"0x", _::binary-64>> = hash) do
    case Utils.hex_decode(hash) do
      {:ok, decoded} -> {:ok, decoded}
      :error -> {:error, :invalid_hash}
    end
  end

  defp normalize_hash(_hash), do: {:error, :invalid_hash}

  defp normalize_signature("0x" <> _ = signature) do
    case Utils.hex_decode(signature) do
      {:ok, decoded} -> {:ok, decoded}
      :error -> {:error, :invalid_signature}
    end
  end

  defp normalize_signature(signature) when is_binary(signature), do: {:ok, signature}

  defp normalize_address(address) do
    with true <- is_binary(address),
         {:ok, address_bin} <- Utils.decode_address(address) do
      {:ok, address_bin}
    else
      _ -> {:error, :invalid_address}
    end
  end

  defp ecrecover_match?(hash, <<r::binary-size(32), s::binary-size(32), v>>, address_bin)
       when v in [0, 1, 27, 28] do
    recovery_id = if v in [1, 28], do: 1, else: 0

    case Ethers.secp256k1_module().recover(hash, r, s, recovery_id) do
      {:ok, public_key} ->
        Utils.public_key_to_address(public_key, false) |> Utils.decode_address!() == address_bin

      {:error, _reason} ->
        false
    end
  end

  defp ecrecover_match?(_hash, _signature, _address_bin), do: false

  defp validate_on_chain(hash, signature, address_bin, opts) do
    {rpc_client, rpc_opts} = get_rpc_client(opts)

    data = UniversalSigValidator.encode_validation_call(address_bin, hash, signature)

    case rpc_client.eth_call(%{data: Utils.hex_encode(data)}, block(opts), rpc_opts) do
      {:ok, "0x01"} -> {:ok, true}
      {:ok, result} when result in ["0x00", "0x"] -> {:ok, false}
      {:ok, result} -> {:error, {:unexpected_result, result}}
      {:error, reason} -> handle_rpc_error(reason)
    end
  end

  # The validator reverts (rather than returning 0x00) for some invalid signatures —
  # e.g. a malformed 65-byte signature on the ecrecover path. Execution reverts mean
  # "invalid signature"; anything else is a real error and gets passed through.
  defp handle_rpc_error(%{"code" => 3} = _reason), do: {:ok, false}

  defp handle_rpc_error(%{"message" => message} = reason) when is_binary(message) do
    if String.contains?(String.downcase(message), "revert") do
      {:ok, false}
    else
      {:error, reason}
    end
  end

  defp handle_rpc_error(reason), do: {:error, reason}

  defp block(opts) do
    case Keyword.get(opts, :block, "latest") do
      number when is_integer(number) -> Utils.integer_to_hex(number)
      tag when is_binary(tag) -> tag
    end
  end
end
