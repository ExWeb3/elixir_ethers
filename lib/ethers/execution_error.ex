defmodule Ethers.ExecutionError do
  @moduledoc """
  Execution Error Exception
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
