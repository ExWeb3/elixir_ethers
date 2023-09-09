// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract MultiClause {
    function next() public pure returns (uint256) {
        return 0;
    }

    function next(uint256 _n) public pure returns (uint256) {
        return _n + 1;
    }

    event Next(int256 indexed n);
    event Next(string indexed n, string indexed b);
}
