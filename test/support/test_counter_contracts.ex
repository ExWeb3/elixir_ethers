defmodule Ethers.Contract.Test.CounterContract do
  use Ethers.Contract, abi_file: "tmp/counter_abi.json"
end

defmodule Ethers.Contract.Test.RegistryContract do
  use Ethers.Contract, abi_file: "tmp/registry_abi.json"
end

defmodule Ethers.Contract.Test.TypesContract do
  use Ethers.Contract, abi_file: "tmp/types_abi.json"
end

defmodule Ethers.Contract.Test.OwnerContract do
  use Ethers.Contract, abi_file: "tmp/owner_abi.json"
end
