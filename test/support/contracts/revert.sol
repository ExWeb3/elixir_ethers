// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract Revert {
    function get(bool success) public pure returns (bool) {
        require(success, "success must be true");
        return true;
    }
}
