test_contracts_path = "test/support/contracts/"
File.mkdir_p!("tmp")

for file <- File.ls!(test_contracts_path) do
  [name, "sol"] = String.split(file, ".")

  {_, 0} =
    System.cmd(
      "/bin/bash",
      [
        "-c",
        "solc #{Path.join(test_contracts_path, name)}.sol --combined-json abi,bin | jq \".contracts | to_entries | .[0].value\" > tmp/#{name}_abi.json"
      ]
    )
end
