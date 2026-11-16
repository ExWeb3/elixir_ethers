# Runs the runnable examples of the documentation, so that they cannot silently go stale.
#
#     mix run test/doc_examples.exs README.md guides/tour.livemd
#
# In `.livemd` files every Elixir cell is evaluated, in order. In other files only the code
# blocks that start with `Mix.install` are evaluated, since those are complete scripts.
#
# The examples run against this checkout: `Mix.install` itself is not executed, only its
# `:config` option is applied. They need network access to the RPC endpoint they configure.

defmodule DocExamples do
  @fence ~r/^```elixir\n(.*?)^```$/ms

  def run(path) do
    source = File.read!(path)

    blocks =
      for [{start, _}, {offset, length}] <- Regex.scan(@fence, source, return: :index),
          code = binary_part(source, offset, length),
          runnable?(path, code) do
        {line_of(source, start) + 1, code}
      end

    if blocks == [], do: raise("no runnable examples found in #{path}")

    Enum.reduce(blocks, {[], Code.env_for_eval(file: path)}, fn {line, code}, {binding, env} ->
      IO.puts("#{path}:#{line}")
      evaluate(code, path, line, binding, env)
    end)
  end

  defp runnable?(path, code) do
    Path.extname(path) == ".livemd" or String.starts_with?(code, "Mix.install")
  end

  defp line_of(source, offset) do
    source |> binary_part(0, offset) |> String.split("\n") |> length()
  end

  defp evaluate(code, path, line, binding, env) do
    quoted = code |> Code.string_to_quoted!(file: path, line: line) |> apply_install()
    {result, binding, env} = Code.eval_quoted_with_env(quoted, binding, env)
    IO.puts("  #=> " <> inspect(result, limit: 6, printable_limit: 70))
    {binding, env}
  end

  # Replaces `Mix.install(deps, config: config)` with applying `config`
  defp apply_install({:__block__, meta, expressions}),
    do: {:__block__, meta, Enum.map(expressions, &apply_install/1)}

  defp apply_install({{:., _, [{:__aliases__, _, [:Mix]}, :install]}, _, [_deps | rest]}) do
    config = rest |> List.first([]) |> Keyword.get(:config, [])
    quote do: Application.put_all_env(unquote(config))
  end

  defp apply_install(expression), do: expression
end

case System.argv() do
  [] -> raise "usage: mix run test/doc_examples.exs FILE..."
  paths -> Enum.each(paths, &DocExamples.run/1)
end

IO.puts("All documentation examples ran.")
