// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract Owner {
    address _owner;

    constructor(address owner) {
        _owner = owner;
    }

    function getOwner() public view returns (address) {
        return _owner;
    }

    error NotOwner();

    function changeOwner(address newOwner) public {
        if (msg.sender != _owner) revert NotOwner();
        _owner = newOwner;
    }
}
