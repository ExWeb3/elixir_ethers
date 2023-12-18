defmodule Ethers.Signer.JsonRPC do
  @moduledoc """
  Signer capable of signing transactions with a JSON RPC server
  capable of `eth_signTransaction` and `eth_accounts` RPC functions.
  """

  @behaviour Ethers.Signer

  alias Ethers.Transaction

  @impl true
  def sign_transaction(%Transaction{} = tx, opts) do
    tx_map = Transaction.to_map(tx)
    {rpc_module, opts} = Keyword.pop(opts, :rpc_module, Ethereumex.HttpClient)

    rpc_module.request("eth_signTransaction", [tx_map], opts)
  end

  @impl true
  def accounts(opts) do
    {rpc_module, opts} = Keyword.pop(opts, :rpc_module, Ethereumex.HttpClient)

    rpc_module.request("eth_accounts", [], opts)
  end
end
