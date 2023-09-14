// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract MultiClause {
    uint256 gn;

    function say(uint256 n) public pure returns (string memory) {
        require(n > 100);
        return "uint256";
    }

    function say(int256 n) public pure returns (string memory) {
        require(n > 100);
        return "int256";
    }

    function say(uint128 n) public pure returns (string memory) {
        require(n > 100);
        return "uint128";
    }

    function say(address n) public pure returns (string memory) {
        require(n != address(0));
        return "address";
    }

    function say(string memory n) public pure returns (string memory) {
        require(bytes(n).length > 0);
        return "string";
    }

    function say(uint8 n) public view returns (string memory) {
        if (n == gn) {
            return "uint8";
        } else {
            revert("Impossible");
        }
    }

    function smart(uint8 n) public pure returns (string memory) {
        require(n != 0);
        return "uint8";
    }

    function smart(int8 n) public pure returns (string memory) {
        require(n != 0);
        return "int8";
    }

    event Said(uint256 indexed n);
    event Said(int256 indexed n);
    event Said(int128 indexed n);
    event Said(address indexed n);
    event Said(string indexed n);
}
