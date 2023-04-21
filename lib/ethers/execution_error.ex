defmodule Ethers.ExecutionError do
  @moduledoc """
  Execution Error Exception.

  The Exception struct will have these values:

  - `message`: A human readable message for the exception.
  - `function`: The contract function which caused the exception.
  - `args`: The arguments for the function causing exception.
  - `error`: The error reason for the exception.
  """

  defexception [:message, :function, :args, :error]

  @impl true
  def exception(error_data) do
    function = error_data[:function]
    args = error_data[:args]
    error = error_data[:error]

    %__MODULE__{
      message:
        error_data[:message] ||
          "Execution failed in `#{function}/#{Enum.count(args)}` -- #{inspect(error)}",
      function: function,
      args: args,
      error: error
    }
  end
end
