// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract Counter {
    uint256 public storeAmount;

    constructor(uint256 initialAmount) {
        storeAmount = initialAmount;
    }

    function get() public view returns (uint256 amount) {
        return storeAmount;
    }

    function getNoReturnName() public view returns (uint256) {
        return storeAmount;
    }

    function set(uint256 newAmount) public {
        emit SetCalled(storeAmount, newAmount);
        storeAmount = newAmount;
    }

    event SetCalled(uint256 indexed oldAmount, uint256 newAmount);
}
