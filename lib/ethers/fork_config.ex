defmodule Ethers.ForkConfig do
  @moduledoc """
  Configuration of a fork as reported by a node through the `eth_config` RPC method
  ([EIP-7910](https://eips.ethereum.org/EIPS/eip-7910)).

  `Ethers.config/1` returns one of these structs for the fork currently in effect
  (`:current`), the next scheduled fork (`:next`) and the last configured fork (`:last`).
  Each struct holds the complete configuration of its fork, not a delta to the previous
  one: activation time, blob schedule, chain id, fork id, precompiles and system contracts.
  See `t:t/0` for the fields and how each of them is decoded.

  Decoding rules:

  - Quantities are decoded to integers.
  - Precompile and system contract names are kept as the strings returned by the node (the
    names used by the EIPs defining them), since each fork can add or remove entries.
  - Addresses are checksummed, like the other addresses the library decodes.
  - A member the node omits (e.g. `activation_time` of a fork without a scheduled
    activation time, or `system_contracts` of a pre-Cancun fork) is `nil`.
  - Members not defined by EIP-7910 are ignored, so newer nodes adding members do not
    break decoding.

  ## Example

      %Ethers.ForkConfig{
        activation_time: 1746612311,
        blob_schedule: %{base_fee_update_fraction: 5007716, max: 9, target: 6},
        chain_id: 1,
        fork_id: "0x3ff0e375",
        precompiles: %{
          "BLAKE2F" => "0x0000000000000000000000000000000000000009",
          "ECREC" => "0x0000000000000000000000000000000000000001",
          ...
        },
        system_contracts: %{
          "BEACON_ROOTS_ADDRESS" => "0x000F3df6D732807Ef1319fB7B8bB8522d0Beac02",
          ...
        }
      }
  """

  alias Ethers.Types
  alias Ethers.Utils

  defstruct [
    :activation_time,
    :blob_schedule,
    :chain_id,
    :fork_id,
    :precompiles,
    :system_contracts
  ]

  @typedoc """
  Blob parameters of a fork:

  - `target` - target number of blobs per block.
  - `max` - maximum number of blobs per block.
  - `base_fee_update_fraction` - the fraction controlling how fast the blob base fee
    adjusts.
  """
  @type blob_schedule :: %{
          target: non_neg_integer(),
          max: non_neg_integer(),
          base_fee_update_fraction: non_neg_integer()
        }

  @typedoc """
  A fork configuration with the following fields (`nil` when the node omits the member):

  - `activation_time` - activation timestamp of the fork in Unix epoch seconds (UTC), as
    an integer. The actual activation time for the current fork and the scheduled time for
    the next and last forks. `0` for a fork active since genesis.
  - `blob_schedule` - blob parameters of the fork, see `t:blob_schedule/0`.
  - `chain_id` - chain id, decoded to an integer.
  - `fork_id` - the [EIP-6122](https://eips.ethereum.org/EIPS/eip-6122) `FORK_HASH` of the
    fork, kept as returned by the node: a lowercase `0x` prefixed hex string of exactly 4
    bytes (e.g. `"0x0929e24e"`). It is an identifier and not a quantity, so it is not
    decoded to an integer; the fixed width canonical form keeps it directly comparable with
    the fork ids reported by other clients and tools.
  - `precompiles` - active precompiled contracts, a map of contract name to checksummed
    address. (e.g. `%{"ECREC" => "0x0000000000000000000000000000000000000001", ...}`)
    Precompiles removed or replaced by a fork are not included.
  - `system_contracts` - system contracts of the fork, a map of contract name to
    checksummed address.
    (e.g. `%{"BEACON_ROOTS_ADDRESS" => "0x000F3df6D732807Ef1319fB7B8bB8522d0Beac02", ...}`)
  """
  @type t :: %__MODULE__{
          activation_time: non_neg_integer() | nil,
          blob_schedule: blob_schedule() | nil,
          chain_id: pos_integer() | nil,
          fork_id: <<_::80>> | nil,
          precompiles: %{optional(String.t()) => Types.t_address()} | nil,
          system_contracts: %{optional(String.t()) => Types.t_address()} | nil
        }

  @doc false
  @spec from_rpc_map(map() | nil) :: t() | nil
  def from_rpc_map(nil), do: nil

  def from_rpc_map(config) when is_map(config) do
    %__MODULE__{
      # JSON numbers per spec (already integers), only chainId is a hex encoded quantity
      activation_time: Map.get(config, "activationTime"),
      blob_schedule: config |> Map.get("blobSchedule") |> decode_blob_schedule(),
      chain_id: config |> Map.get("chainId") |> decode_quantity(),
      # Fixed width 4-byte identifier, kept in its canonical form
      fork_id: Map.get(config, "forkId"),
      precompiles: config |> Map.get("precompiles") |> decode_named_addresses(),
      system_contracts: config |> Map.get("systemContracts") |> decode_named_addresses()
    }
  end

  defp decode_blob_schedule(nil), do: nil

  defp decode_blob_schedule(blob_schedule) when is_map(blob_schedule) do
    %{
      base_fee_update_fraction: Map.get(blob_schedule, "baseFeeUpdateFraction"),
      max: Map.get(blob_schedule, "max"),
      target: Map.get(blob_schedule, "target")
    }
  end

  defp decode_quantity(nil), do: nil
  defp decode_quantity(hex), do: Utils.hex_to_integer!(hex)

  # Names stay strings: they are open-ended (defined per fork) and come from the node
  defp decode_named_addresses(nil), do: nil

  defp decode_named_addresses(addresses) when is_map(addresses),
    do:
      Map.new(addresses, fn {name, address} -> {name, Utils.maybe_checksum_address(address)} end)
end
