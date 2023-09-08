defmodule Ethers.ExecutionError do
  @moduledoc """
  Execution Error Exception.

  The Exception struct will have these values:

  - `message`: A string message regarding the exception.
  - `evm_error`: Usually a map containing the error detail returned as is by the RPC server.
  """

  defexception [:message, :evm_error]

  @impl true
  def exception(evm_error) do
    %__MODULE__{
      message: evm_error["message"] || "unknown error!",
      evm_error: evm_error
    }
  end
end
