defmodule Ethers.Transaction do
  @moduledoc """
  Transaction struct and helper functions
  """

  alias Ethers.Types
  alias Ethers.Utils

  @enforce_keys [:type]
  defstruct [
    :type,
    chain_id: nil,
    nonce: nil,
    gas: nil,
    from: nil,
    to: nil,
    value: "0x0",
    data: "",
    gas_price: nil,
    max_fee_per_gas: nil,
    max_priority_fee_per_gas: "0x0",
    access_list: [],
    signature_r: nil,
    signature_s: nil,
    signature_recovery_id: nil,
    block_hash: nil,
    block_number: nil,
    hash: nil,
    input: nil,
    transaction_index: nil,
    v: nil,
    y_parity: nil
  ]

  @type t_transaction_type :: :legacy | :eip1559
  @type t :: %__MODULE__{
          type: t_transaction_type(),
          chain_id: binary() | nil,
          nonce: binary() | nil,
          gas: binary() | nil,
          from: Types.t_address() | nil,
          to: Types.t_address() | nil,
          value: binary(),
          data: binary(),
          gas_price: binary() | nil,
          max_fee_per_gas: binary() | nil,
          max_priority_fee_per_gas: binary(),
          access_list: [{binary(), [binary()]}],
          signature_r: binary() | nil,
          signature_s: binary() | nil,
          signature_recovery_id: 0 | 1 | nil,
          block_hash: binary() | nil,
          block_number: binary() | nil,
          hash: binary() | nil,
          input: binary() | nil,
          transaction_index: binary() | nil,
          v: binary() | nil,
          y_parity: binary() | nil
        }

  @common_fillable_params [:chain_id, :nonce]
  @type_fillable_params %{
    legacy: [:gas_price],
    eip1559: [:max_fee_per_gas]
  }

  def new(params, type \\ :eip1559) do
    struct!(__MODULE__, Map.put(params, :type, type))
  end

  def fill_with_defaults(%__MODULE__{type: type} = tx, opts) do
    {keys, actions} =
      tx
      |> Map.from_struct()
      |> Map.take(@common_fillable_params ++ Map.get(@type_fillable_params, type))
      |> Enum.filter(fn {_k, v} -> is_nil(v) end)
      |> Enum.map(&elem(&1, 0))
      |> Enum.map(&{&1, fill_action(&1, tx)})
      |> Enum.filter(&elem(&1, 1))
      |> Enum.unzip()

    if actions == [] do
      {:ok, tx}
    else
      with {:ok, results} <- Ethers.batch(actions, opts),
           {:ok, defaults} <- post_process(keys, results, []) do
        {:ok, Map.merge(tx, defaults)}
      end
    end
  end

  def encode(%{type: :legacy} = tx) do
    [
      tx.nonce,
      tx.gas_price,
      tx.gas,
      tx.to,
      tx.value,
      tx.data
    ]
    |> Enum.map(&(&1 || ""))
    |> maybe_add_signature(tx)
    |> convert_to_binary()
    |> ExRLP.encode()
  end

  def encode(%{type: :eip1559} = tx) do
    [
      tx.chain_id,
      tx.nonce,
      tx.max_priority_fee_per_gas,
      tx.max_fee_per_gas,
      tx.gas,
      tx.to,
      tx.value,
      tx.data,
      tx.access_list
    ]
    |> Enum.map(&(&1 || ""))
    |> maybe_add_signature(tx)
    |> convert_to_binary()
    |> ExRLP.encode()
    |> then(&(<<2>> <> &1))
  end

  def decode(%{"type" => encoded_type} = tx) do
    type =
      case Ethers.Utils.hex_to_integer!(encoded_type) do
        2 -> :eip1559
        _ -> :legacy
      end

    tx_body =
      %{
        chain_id: Map.get(tx, "chainId"),
        nonce: Map.get(tx, "nonce"),
        gas: Map.get(tx, "gas"),
        gas_price: Map.get(tx, "gasPrice"),
        max_fee_per_gas: Map.get(tx, "maxFeePerGas"),
        max_priority_fee_per_gas: Map.get(tx, "maxPriorityFeePerGas"),
        block_number: Map.get(tx, "blockNumber"),
        transaction_index: Map.get(tx, "transactionIndex"),
        v: Map.get(tx, "v"),
        y_parity: Map.get(tx, "yParity")
      }
      |> Enum.map(fn {k, v} ->
        decoded_value =
          case v do
            nil -> nil
            _ -> Ethers.Utils.hex_to_integer!(v)
          end

        {k, decoded_value}
      end)
      |> Enum.into(%{})
      |> Map.merge(%{
        type: type,
        from: Map.get(tx, "from"),
        to: Map.get(tx, "to"),
        data: nil,
        access_list: Map.get(tx, "accessList"),
        signature_r: Map.get(tx, "r"),
        signature_s: Map.get(tx, "s"),
        signature_recovery_id: nil,
        block_hash: Map.get(tx, "blockHash"),
        hash: Map.get(tx, "hash"),
        input: Map.get(tx, "input")
      })
      |> new()

    {:ok, tx_body}
  end

  def to_map(%{type: :eip1559} = tx) do
    %{
      from: tx.from,
      to: tx.to,
      gas: tx.gas,
      maxPriorityFeePerGas: tx.max_priority_fee_per_gas,
      maxFeePerGas: tx.max_fee_per_gas,
      nonce: tx.nonce,
      value: tx.value,
      data: tx.data
    }
  end

  def to_map(%{type: :legacy} = tx) do
    %{
      from: tx.from,
      to: tx.to,
      gas: tx.gas,
      gasPrice: tx.gas_price,
      nonce: tx.nonce,
      value: tx.value,
      data: tx.data
    }
  end

  defp maybe_add_signature(tx_list, tx) do
    case tx do
      %{signature_r: r, signature_s: s, signature_recovery_id: rec_id} when not is_nil(r) ->
        y_parity =
          case tx do
            %{type: :legacy, chain_id: chain_id} when not is_nil(chain_id) ->
              # EIP-155
              chain_id = Ethers.Utils.hex_to_integer!(chain_id)
              rec_id + 35 + chain_id * 2

            %{type: :legacy} ->
              # EIP-155
              rec_id + 27

            _ ->
              # EIP-1559
              rec_id
          end

        tx_list ++ [y_parity, trim_leading(r), trim_leading(s)]

      %{type: :legacy, chain_id: chain_id} when not is_nil(chain_id) ->
        # EIP-155 encoding for signature mitigation intra-chain replay attack
        tx_list ++ [chain_id, 0, 0]

      _ ->
        tx_list
    end
  end

  defp fill_action(:chain_id, _tx), do: :chain_id
  defp fill_action(:nonce, tx), do: {:get_transaction_count, [tx.from, "latest"]}
  defp fill_action(:max_fee_per_gas, _tx), do: :gas_price
  defp fill_action(:gas_price, _tx), do: :gas_price

  defp post_process([], [], acc), do: {:ok, Enum.into(acc, %{})}

  defp post_process([k | tk], [v | tv], acc) do
    with {:ok, item} <- do_post_process(k, v) do
      post_process(tk, tv, [item | acc])
    end
  end

  defp do_post_process(:max_fee_per_gas, {:ok, v_hex}) do
    with {:ok, v} <- Utils.hex_to_integer(v_hex) do
      # Setting a higher value for max_fee_per gas since the actual base fee is
      # determined by the last block. This way we minimize the chance to get stuck in
      # queue when base fee increases
      mex_fee_per_gas = div(v * 120, 100)
      {:ok, {:max_fee_per_gas, Utils.integer_to_hex(mex_fee_per_gas)}}
    end
  end

  defp do_post_process(key, {:ok, v_hex}) do
    {:ok, {key, v_hex}}
  end

  defp do_post_process(_key, {:error, reason}), do: {:error, reason}

  defp convert_to_binary(list) do
    Enum.map(list, fn
      "0x" <> _ = bin ->
        bin
        |> Ethers.Utils.hex_decode!()
        |> trim_leading()

      l when is_list(l) ->
        convert_to_binary(l)

      item ->
        item
    end)
  end

  defp trim_leading(<<0, rest::binary>>), do: trim_leading(rest)
  defp trim_leading(<<bin::binary>>), do: bin
end
