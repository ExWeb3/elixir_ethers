// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// Minimal CREATE2 factory used to test ERC-6492 counterfactual signature
// verification in `Ethers.Signature`.
contract Create2Factory {
    function deploy(
        bytes32 salt,
        bytes memory initCode
    ) public returns (address addr) {
        assembly {
            addr := create2(0, add(initCode, 0x20), mload(initCode), salt)
        }
        require(addr != address(0), "CREATE2 failed");
    }
}
