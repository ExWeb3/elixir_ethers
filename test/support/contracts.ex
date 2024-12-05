# Contracts which require compile time consolidation
# (For now the ones testing Inspect protocol)

defmodule Ethers.Contract.Test.RevertContract do
  @moduledoc false
  use Ethers.Contract, abi_file: "tmp/revert_abi.json"
end

defmodule Ethers.Contract.Test.CcipReadTestContract do
  @moduledoc false
  use Ethers.Contract, abi_file: "tmp/ccip_read_abi.json"
end
