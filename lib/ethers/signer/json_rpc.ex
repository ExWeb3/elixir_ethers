defmodule Ethers.Signer.JsonRPC do
  @moduledoc """
  Signer capable of signing transactions with a JSON RPC server
  capable of `eth_signTransaction`, `eth_signTypedData_v4`, `personal_sign` and `eth_accounts`
  RPC functions.

  ## Signer Options

  - `:rpc_module`: The RPC Module to use. (Optional, Defaults to `Ethereumex.HttpClient`)
  - `:url`: The RPC URL to use. (Optional)

  ** All other options will be passed to the RPC module `request/3` function in
  the third argument **
  """

  @behaviour Ethers.Signer

  alias Ethers.Transaction

  @impl true
  def sign_transaction(tx, opts) do
    tx_map = Transaction.to_rpc_map(tx)

    tx_map =
      if from = Keyword.get(opts, :from) do
        Map.put_new(tx_map, :from, from)
      else
        tx_map
      end

    {rpc_module, opts} = Keyword.pop(opts, :rpc_module, Ethereumex.HttpClient)

    rpc_module.request("eth_signTransaction", [tx_map], opts)
  end

  @impl true
  def sign_typed_data(typed_data, opts) do
    case Keyword.get(opts, :from) do
      nil ->
        {:error, :missing_from_address}

      from ->
        {rpc_module, opts} = Keyword.pop(opts, :rpc_module, Ethereumex.HttpClient)

        json =
          typed_data
          |> Ethers.TypedData.to_eip712_json()
          |> Jason.encode!()

        rpc_module.request("eth_signTypedData_v4", [from, json], opts)
    end
  end

  @impl true
  def personal_sign(message, opts) do
    case Keyword.get(opts, :from) do
      nil ->
        {:error, :missing_from_address}

      from ->
        {rpc_module, opts} = Keyword.pop(opts, :rpc_module, Ethereumex.HttpClient)

        rpc_module.request("personal_sign", [Ethers.Utils.hex_encode(message), from], opts)
    end
  end

  @impl true
  def accounts(opts) do
    {rpc_module, opts} = Keyword.pop(opts, :rpc_module, Ethereumex.HttpClient)

    rpc_module.request("eth_accounts", [], opts)
  end
end
