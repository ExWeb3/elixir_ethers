// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract EventArgumentTypes {
    struct InnerType {
        uint256 number0;
        uint256 number1;
        uint256 number2;
    }

    event TestEvent(uint256[3] indexed numbers, bool has_won);
    event TestEvent(uint256[] indexed numbers, bool has_won);
    event TestEvent(InnerType indexed numbers, bool has_won);
    event TestEvent(string indexed numbers, bool has_won);
    event TestEvent(bytes indexed numbers, bool has_won);
}
