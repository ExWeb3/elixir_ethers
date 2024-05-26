defmodule Ethers.ExecutionError do
  @moduledoc """
  Execution Error Exception.

  The Exception struct will have these values:

  - `message`: Human readable error message
  - `evm_error`: A custom error from the contract. (An Error Struct)
  """

  defexception [:message, :evm_error]

  @impl true
  def exception(%{"code" => _} = evm_error) do
    %__MODULE__{
      message: Map.get(evm_error, "message", "unknown error!"),
      evm_error: evm_error
    }
  end

  def exception(error) when is_exception(error), do: error

  def exception(error) when is_struct(error) do
    %__MODULE__{message: inspect(error), evm_error: error}
  end

  def exception(error) do
    %__MODULE__{message: "Unexpected error: #{maybe_inspect_error(error)}"}
  end

  defp maybe_inspect_error(error) when is_atom(error), do: Atom.to_string(error)
  defp maybe_inspect_error(error), do: inspect(error)
end
