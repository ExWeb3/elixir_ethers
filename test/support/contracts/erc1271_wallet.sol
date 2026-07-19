// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// Minimal ERC-1271 smart-contract wallet used to test `Ethers.Signature`.
// Returns the ERC-1271 magic value when the signature over `hash` was produced
// by the configured owner EOA.
contract ERC1271Wallet {
    bytes4 internal constant MAGICVALUE = 0x1626ba7e;

    address public owner;

    constructor(address _owner) {
        owner = _owner;
    }

    function isValidSignature(
        bytes32 hash,
        bytes memory signature
    ) public view returns (bytes4) {
        if (signature.length != 65) {
            return 0xffffffff;
        }

        bytes32 r;
        bytes32 s;
        uint8 v;

        assembly {
            r := mload(add(signature, 0x20))
            s := mload(add(signature, 0x40))
            v := byte(0, mload(add(signature, 0x60)))
        }

        if (v < 27) {
            v += 27;
        }

        if (ecrecover(hash, v, r, s) == owner) {
            return MAGICVALUE;
        }

        return 0xffffffff;
    }
}
