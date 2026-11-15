test_contracts_path = "test/support/contracts/"
File.mkdir_p!("tmp")

for tool <- ["solc", "jq"], is_nil(System.find_executable(tool)) do
  raise "test preparation requires `#{tool}` to be installed and in PATH"
end

for file <- File.ls!(test_contracts_path) do
  [name, "sol"] = String.split(file, ".")
  abi_path = "tmp/#{name}_abi.json"
  tmp_abi_path = abi_path <> ".tmp"

  # pipefail makes a solc failure fail the pipeline instead of jq's exit status winning.
  # Output goes to a temporary file so a failure never leaves an empty or partial ABI file.
  case System.cmd(
         "/bin/bash",
         [
           "-c",
           "set -o pipefail; solc #{Path.join(test_contracts_path, name)}.sol --combined-json abi,bin | jq \".contracts | to_entries | .[0].value\" > #{tmp_abi_path}"
         ]
       ) do
    {_, 0} ->
      File.rename!(tmp_abi_path, abi_path)

    {_, status} ->
      File.rm(tmp_abi_path)
      raise "compiling #{file} with solc failed (exit status #{status}), see the output above"
  end
end
