// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract EventMixedIndex {
    function transfer(
        uint256 amount,
        address sender,
        bool isFinal,
        address receiver
    ) public {
        emit Transfer(amount, sender, isFinal, receiver);
    }

    event Transfer(
        uint256 amount,
        address indexed sender,
        bool isFinal,
        address indexed receiver
    );
}
