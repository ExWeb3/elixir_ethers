// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract EventMixedIndex {
    event Transfer(
        uint256 amount,
        address indexed sender,
        bool isFinal,
        address indexed receiver
    );
}
