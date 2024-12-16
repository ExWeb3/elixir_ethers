defmodule Ethers.Utils do
  @moduledoc """
  Utilities for interacting with ethereum blockchain
  """

  @wei_multiplier trunc(:math.pow(10, 18))
  # Use 5 thousand blocks to determine the average block time
  @default_sample_size 5_000
  # Default acceptable drift for datetime to blocknumber is 10 ethereum mainnet blocks (12s)
  @default_acceptable_drift 12 * 10
  # Safety margin is the percentage to add to gas when no gas
  # limit is provided by the user to prevent out-of-gas errors.
  # Default is 10% (=110)
  @gas_safety_margin 110

  @doc """
  Encode to hex with 0x prefix.

  ## Examples

      iex> Ethers.Utils.hex_encode("ethers_ex")
      "0x6574686572735f6578"
  """
  @spec hex_encode(binary()) :: String.t()
  def hex_encode(bin, include_prefix \\ true),
    do: if(include_prefix, do: "0x", else: "") <> Base.encode16(bin, case: :lower)

  @doc """
  Decode from hex with (or without) 0x prefix.

  ## Examples

      iex> Ethers.Utils.hex_decode("0x6574686572735f6578")
      {:ok, "ethers_ex"}

      iex> Ethers.Utils.hex_decode("6574686572735f6578")
      {:ok, "ethers_ex"}

      iex> Ethers.Utils.hex_decode("0x686")
      {:ok, <<6, 134>>}
  """
  @spec hex_decode(String.t()) :: {:ok, binary} | :error
  def hex_decode(<<"0x", encoded::binary>>), do: hex_decode(encoded)
  def hex_decode(encoded) when rem(byte_size(encoded), 2) == 1, do: hex_decode("0" <> encoded)
  def hex_decode(encoded), do: Base.decode16(encoded, case: :mixed)

  @doc """
  Same as `hex_decode/1` but raises on error

  ## Examples

      iex> Ethers.Utils.hex_decode!("0x6574686572735f6578")
      "ethers_ex"

      iex> Ethers.Utils.hex_decode!("6574686572735f6578")
      "ethers_ex"
  """
  @spec hex_decode!(String.t()) :: binary() | no_return()
  def hex_decode!(encoded) do
    case hex_decode(encoded) do
      {:ok, decoded} -> decoded
      :error -> raise ArgumentError, "Invalid HEX input #{inspect(encoded)}"
    end
  end

  @doc """
  Converts a hexadecimal integer to integer form

  ## Examples

      iex> Ethers.Utils.hex_to_integer("0x11111")
      {:ok, 69905}
  """
  @spec hex_to_integer(String.t()) :: {:ok, non_neg_integer()} | {:error, :invalid_hex}
  def hex_to_integer(<<"0x", "-", _::binary>>), do: {:error, :invalid_hex}
  def hex_to_integer(<<"0x", encoded::binary>>), do: hex_to_integer(encoded)

  def hex_to_integer(encoded) do
    case Integer.parse(encoded, 16) do
      {integer, ""} ->
        {:ok, integer}

      _ ->
        {:error, :invalid_hex}
    end
  end

  @doc """
  Same as `hex_to_integer/1` but raises on error

  ## Examples

      iex> Ethers.Utils.hex_to_integer!("0x11111")
      69905
  """
  @spec hex_to_integer!(String.t()) :: non_neg_integer() | no_return()
  def hex_to_integer!(encoded) do
    case hex_to_integer(encoded) do
      {:ok, integer} ->
        integer

      {:error, reason} ->
        raise ArgumentError,
              "Invalid integer HEX input #{inspect(encoded)} reason #{inspect(reason)}"
    end
  end

  @doc """
  Converts integer to its hexadecimal form

  ## Examples

      iex> Ethers.Utils.integer_to_hex(69905)
      "0x11111"
  """
  @spec integer_to_hex(non_neg_integer()) :: String.t()
  def integer_to_hex(integer) when is_integer(integer) and integer >= 0 do
    "0x" <> Integer.to_string(integer, 16)
  end

  @doc """
  Converts ETH to WEI

  ## Examples

      iex> Ethers.Utils.to_wei(1)
      1000000000000000000

      iex> Ethers.Utils.to_wei(3.14)
      3140000000000000000

      iex> Ethers.Utils.to_wei(0)
      0

      iex> Ethers.Utils.to_wei(-10)
      -10000000000000000000
  """
  @spec to_wei(number()) :: integer()
  def to_wei(number) do
    trunc(number * @wei_multiplier)
  end

  @doc """
  Convert WEI to ETH

  ## Examples

      iex> Ethers.Utils.from_wei(1000000000000000000)
      1.0

      iex> Ethers.Utils.from_wei(3140000000000000000)
      3.14

      iex> Ethers.Utils.from_wei(-10000000000000000000)
      -10.0
  """
  @spec from_wei(integer()) :: float()
  def from_wei(number) when is_integer(number) do
    number / @wei_multiplier
  end

  @doc """
  Adds gas limit estimation to the parameters if not already exists

  If option `mult` is given, a gas limit multiplied by `mult` divided by 1000 will be used.
  Default for `mult` is 100. (1%)
  """
  @deprecated "Use Ethers.estimate_gas/2 instead"
  def maybe_add_gas_limit(params, opts \\ [])

  def maybe_add_gas_limit(%{gas: _} = params, _opts) do
    {:ok, params}
  end

  def maybe_add_gas_limit(params, opts) do
    with {:ok, gas} <- Ethers.estimate_gas(params, opts) do
      gas = div(@gas_safety_margin * gas, 100) |> integer_to_hex()
      {:ok, Map.put(params, :gas, gas)}
    end
  end

  @doc """
  Converts human readable argument to the form required for ABI encoding.

  For example the addresses in Ethereum are represented by hex strings in human readable format
  but are in 160-bit binaries in ABI form.

  ## Examples
      iex> Ethers.Utils.prepare_arg("0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2", :address)
      <<192, 42, 170, 57, 178, 35, 254, 141, 10, 14, 92, 79, 39, 234, 217, 8, 60, 117, 108, 194>>
  """
  @spec prepare_arg(term(), ABI.FunctionSelector.type()) :: term()
  def prepare_arg("0x" <> _ = argument, :address), do: hex_decode!(argument)
  def prepare_arg(arguments, {:array, type}), do: Enum.map(arguments, &prepare_arg(&1, type))
  def prepare_arg(arguments, {:array, type, _}), do: Enum.map(arguments, &prepare_arg(&1, type))

  def prepare_arg(arguments, {:tuple, types}) do
    arguments
    |> Tuple.to_list()
    |> Enum.zip(types)
    |> Enum.map(fn {arg, type} -> prepare_arg(arg, type) end)
    |> List.to_tuple()
  end

  def prepare_arg(argument, _type), do: argument

  @doc """
  Reverse of `prepare_arg/2`

  ## Examples
      iex> Ethers.Utils.human_arg(<<192, 42, 170, 57, 178, 35, 254, 141, 10, 14, 92, 79, 39,
      ...> 234, 217, 8, 60, 117, 108, 194>>, :address)
      "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2"

      iex> Ethers.Utils.human_arg("0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2", :address)
      "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2"
  """
  @spec human_arg(term(), ABI.FunctionSelector.type()) :: term()
  def human_arg("0x" <> _ = argument, :address), do: argument
  def human_arg(argument, :address), do: hex_encode(argument)

  def human_arg(arguments, {:array, type}), do: Enum.map(arguments, &human_arg(&1, type))
  def human_arg(arguments, {:array, type, _}), do: Enum.map(arguments, &human_arg(&1, type))

  def human_arg(arguments, {:tuple, types}) do
    arguments
    |> Tuple.to_list()
    |> Enum.zip(types)
    |> Enum.map(fn {arg, type} -> human_arg(arg, type) end)
    |> List.to_tuple()
  end

  def human_arg(argument, _type), do: argument

  @doc """
  Will convert an upper or lowercase Ethereum address to a checksum address.

  ## Examples

      iex> Ethers.Utils.to_checksum_address("0xc1912fee45d61c87cc5ea59dae31190fffff232d")
      "0xc1912fEE45d61C87Cc5EA59DaE31190FFFFf232d"

      iex> Ethers.Utils.to_checksum_address("0XC1912FEE45D61C87CC5EA59DAE31190FFFFF232D")
      "0xc1912fEE45d61C87Cc5EA59DaE31190FFFFf232d"
  """
  @spec to_checksum_address(Ethers.Types.t_address()) :: Ethers.Types.t_address()
  def to_checksum_address("0x" <> address), do: to_checksum_address(address)
  def to_checksum_address("0X" <> address), do: to_checksum_address(address)

  def to_checksum_address(<<address_bin::binary-20>>),
    do: hex_encode(address_bin) |> to_checksum_address()

  def to_checksum_address(address) do
    address = String.downcase(address)

    hashed_address =
      address |> Ethers.keccak_module().hash_256() |> Base.encode16(case: :lower)

    checksum_address =
      address
      |> String.to_charlist()
      |> Enum.zip(String.to_charlist(hashed_address))
      |> Enum.map(fn
        {c, _} when c < ?a -> c
        {c, h} when h > ?7 -> :string.to_upper(c)
        {c, _} -> c
      end)
      |> to_string()

    "0x#{checksum_address}"
  end

  @doc """
  Checks the checksum of a given address. Will also return false on non-checksum addresses.

  ## Examples

      iex> Ethers.Utils.valid_checksum_address?("0xc1912fEE45d61C87Cc5EA59DaE31190FFFFf232d")
      true

      iex> Ethers.Utils.valid_checksum_address?("0xc1912fee45d61C87Cc5EA59DaE31190FFFFf232d")
      false
  """
  @spec valid_checksum_address?(Ethers.Types.t_address()) :: boolean()
  def valid_checksum_address?(address) do
    address === to_checksum_address(address)
  end

  @doc """
  Calculates address of a given public key. Public key can be in compressed or decompressed format
  either with or without prefix. It can also be hex encoded.

  ## Examples

      iex> Utils.public_key_to_address("0x04e68acfc0253a10620dff706b0a1b1f1f5833ea3beb3bde2250d5f271f3563606672ebc45e0b7ea2e816ecb70ca03137b1c9476eec63d4632e990020b7b6fba39")
      "0x90F8bf6A479f320ead074411a4B0e7944Ea8c9C1"

      iex> Utils.public_key_to_address("0x03e68acfc0253a10620dff706b0a1b1f1f5833ea3beb3bde2250d5f271f3563606")
      "0x90F8bf6A479f320ead074411a4B0e7944Ea8c9C1"
  """
  @spec public_key_to_address(Ethers.Types.t_pub_key()) :: Ethers.Types.t_address()
  def public_key_to_address(public_key, use_checksum_address \\ true)

  def public_key_to_address(<<public_key::binary-64>>, use_checksum_address) do
    address =
      Ethers.keccak_module().hash_256(public_key)
      |> :binary.part(32 - 20, 20)
      |> hex_encode()

    if use_checksum_address do
      to_checksum_address(address)
    else
      address
    end
  end

  def public_key_to_address(<<4, public_key::binary-64>>, use_checksum_address) do
    public_key_to_address(public_key, use_checksum_address)
  end

  unless Code.ensure_loaded?(Ethers.secp256k1_module()) do
    def public_key_to_address(<<pre, _::binary-32>> = compressed, _use_checksum_address)
        when pre in [2, 3],
        do: raise("secp256k1 module not loaded")
  end

  def public_key_to_address(<<pre, _::binary-32>> = compressed, use_checksum_address)
      when pre in [2, 3] do
    case Ethers.secp256k1_module().public_key_decompress(compressed) do
      {:ok, public_key} -> public_key_to_address(public_key, use_checksum_address)
      error -> raise ArgumentError, "Invalid compressed public key #{inspect(error)}"
    end
  end

  def public_key_to_address("0x" <> _ = key, use_checksum_address) do
    key
    |> hex_decode!()
    |> public_key_to_address(use_checksum_address)
  end

  @doc """
  Returns the timestamp for a given block number.

  The block_number parameter can be a non negative integer or the hex encoded value of that integer.
  (The hex encoding *must* start with 0x prefix)
  """
  @spec get_block_timestamp(non_neg_integer() | String.t(), Keyword.t()) ::
          {:ok, non_neg_integer()} | {:error, :negative_block_number | :block_not_found | term()}
  def get_block_timestamp(block_number, opts \\ [])

  def get_block_timestamp(block_number, opts) when is_integer(block_number) and block_number >= 0,
    do: get_block_timestamp(integer_to_hex(block_number), opts)

  def get_block_timestamp(block_number, _opts) when is_integer(block_number),
    do: {:error, :negative_block_number}

  def get_block_timestamp("0x" <> _ = block_number, opts) do
    {rpc_client, rpc_opts} = Ethers.get_rpc_client(opts)

    case rpc_client.eth_get_block_by_number(block_number, false, rpc_opts) do
      {:ok, nil} ->
        {:error, :block_not_found}

      {:ok, block} when is_map(block) ->
        block |> Map.fetch!("timestamp") |> hex_to_integer()

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Returns the nearest block number to a given date and time.

  ## Parameters
  - date_or_date_time: Can be a `Date`, `DateTime` or an integer unix timestamp.
  - ref_block_number: A block number of reference which is closer to the target block.
    Can make search time faster if given. (Defaults to current block number)
  - opts: Optional extra options.
    - acceptable_drift: Can be set to override the default acceptable_drift of
      #{@default_acceptable_drift} seconds. This value can be reduced for more accurate results.
    - sample_size: Can be set to override the default sample_size of #{@default_sample_size} blocks.
    - backoff_timeout: An optional backoff in milliseconds that will happen between RPC calls.
      (Useful to prevent quote errors)
  """
  @spec date_to_block_number(
          Date.t() | DateTime.t() | non_neg_integer(),
          non_neg_integer() | nil,
          Keyword.t()
        ) :: {:ok, non_neg_integer()} | {:error, term()}
  def date_to_block_number(date_or_date_time, ref_block_number \\ nil, opts \\ [])

  def date_to_block_number(%Date{} = date, ref_block_number, opts) do
    date
    |> DateTime.new!(~T[00:00:00.000], "Etc/UTC")
    |> date_to_block_number(ref_block_number, opts)
  end

  def date_to_block_number(%DateTime{} = datetime, ref_block_number, opts) do
    datetime
    |> DateTime.to_unix()
    |> date_to_block_number(ref_block_number, opts)
  end

  def date_to_block_number(datetime, nil, opts) do
    with {:ok, block_number} <- Ethers.current_block_number(opts) do
      date_to_block_number(datetime, block_number, opts)
    end
  end

  def date_to_block_number(datetime, block_number, opts) when block_number <= 0 do
    acceptable_drift = opts[:acceptable_drift] || @default_acceptable_drift

    with {:ok, current_timestamp} <- get_block_timestamp(0, opts) do
      if abs(datetime - current_timestamp) <= acceptable_drift do
        {:ok, 0}
      else
        {:error, :no_block_found}
      end
    end
  end

  def date_to_block_number(datetime, ref_block_number, opts) when is_integer(datetime) do
    acceptable_drift = opts[:acceptable_drift] || @default_acceptable_drift

    with {:ok, current_timestamp} <- get_block_timestamp(ref_block_number, opts) do
      if abs(datetime - current_timestamp) <= acceptable_drift do
        {:ok, ref_block_number}
      else
        find_and_try_next_block_number(datetime, ref_block_number, current_timestamp, opts)
      end
    end
  end

  defp find_and_try_next_block_number(datetime, ref_block_number, current_timestamp, opts) do
    maybe_backoff(opts)
    sample_size = opts[:sample_size] || @default_sample_size
    sample_start_block_number = max(ref_block_number - sample_size, 0)

    with {:ok, old_timestamp} <- get_block_timestamp(sample_start_block_number, opts) do
      avg_time = (current_timestamp - old_timestamp) / (sample_size + 1)

      new_block_number = ref_block_number - round((current_timestamp - datetime) / avg_time)
      new_block_number = if sample_start_block_number > 0, do: max(new_block_number, 0), else: 0

      date_to_block_number(datetime, new_block_number, opts)
    end
  end

  defp maybe_backoff(opts) do
    if timeout = Keyword.get(opts, :backoff_timeout) do
      Process.sleep(timeout)
    end
  end

  @doc """
  Decode a hex-encoded Ethereum address to its binary form.
  Returns error if the address is invalid (wrong length or invalid hex).

  ## Examples

      iex> Ethers.Utils.decode_address("0x90F8bf6A479f320ead074411a4B0e7944Ea8c9C1")
      {:ok, <<144, 248, 191, 106, 71, 159, 50, 14, 173, 7, 68, 17, 164, 176, 231, 148, 78, 168, 201, 193>>}

      iex> Ethers.Utils.decode_address(nil)
      {:error, :invalid_address}

      iex> Ethers.Utils.decode_address("0xinvalid")
      {:error, :invalid_address}
  """
  @spec decode_address(Types.t_address() | nil) :: {:ok, binary()} | {:error, :invalid_address}
  def decode_address(<<"0x", address::binary-40>>) do
    hex_decode(address)
  end

  def decode_address(_), do: {:error, :invalid_address}

  @doc """
  Same as `decode_address/1` but raises on error.

  ## Examples

      iex> Ethers.Utils.decode_address!("0x90F8bf6A479f320ead074411a4B0e7944Ea8c9C1")
      <<144, 248, 191, 106, 71, 159, 50, 14, 173, 7, 68, 17, 164, 176, 231, 148, 78, 168, 201, 193>>
  """
  @spec decode_address!(Types.t_address() | nil) :: binary() | no_return()
  def decode_address!(address) do
    case decode_address(address) do
      {:ok, decoded} ->
        decoded

      {:error, :invalid_address} ->
        raise ArgumentError, "Invalid Ethereum address #{inspect(address)}"
    end
  end

  @doc """
  Encode a binary Ethereum address to its hex form.
  Returns error if the address is invalid (wrong length).

  ## Examples

      iex> address = <<144, 248, 191, 106, 71, 159, 50, 14, 173, 7, 68, 17, 164, 176, 231, 148, 78, 168, 201, 193>>
      iex> Ethers.Utils.encode_address(address)
      {:ok, "0x90f8bf6a479f320ead074411a4b0e7944ea8c9c1"}

      iex> Ethers.Utils.encode_address(<<1, 2, 3>>)
      {:error, :invalid_address}
  """
  @spec encode_address(binary()) :: {:ok, Types.t_address()} | {:error, :invalid_address}
  def encode_address(address) when byte_size(address) == 20, do: {:ok, hex_encode(address)}
  def encode_address(_), do: {:error, :invalid_address}

  @doc """
  Same as `encode_address/1` but raises on error.

  ## Examples

      iex> address = <<144, 248, 191, 106, 71, 159, 50, 14, 173, 7, 68, 17, 164, 176, 231, 148, 78, 168, 201, 193>>
      iex> Ethers.Utils.encode_address!(address)
      "0x90f8bf6a479f320ead074411a4b0e7944ea8c9c1"
  """
  @spec encode_address!(binary()) :: Types.t_address() | no_return()
  def encode_address!(address) do
    case encode_address(address) do
      {:ok, encoded} ->
        encoded

      {:error, :invalid_address} ->
        raise ArgumentError, "Invalid Ethereum address binary #{inspect(address)}"
    end
  end
end
