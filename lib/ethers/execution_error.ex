defmodule Ethers.ExecutionError do
  @moduledoc """
  Execution Error Exception.

  The Exception struct will have these values:

  - `message`: A string message regarding the exception.
  - `evm_error`: Usually a map containing the error detail returned as is by the RPC server.
  """

  defexception [:message, :evm_error]

  @impl true
  def exception(%{"code" => _} = evm_error) do
    %__MODULE__{
      message: Map.get(evm_error, "message", "unknown error!"),
      evm_error: evm_error
    }
  end

  def exception(error) when is_exception(error),
    do: error

  def exception(error) when is_atom(error) or is_binary(error) do
    %__MODULE__{message: "Unexpected error: #{error}"}
  end
end
