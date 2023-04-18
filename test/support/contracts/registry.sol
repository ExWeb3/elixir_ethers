// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

struct RegisterParams {
    string name;
    uint8 age;
}

contract Registry {
    mapping(address => RegisterParams) registry;

    function register(RegisterParams memory params) public {
        registry[msg.sender] = params;
        emit Registered(msg.sender, params);
    }

    function info(address owner) public view returns (RegisterParams memory) {
        return registry[owner];
    }

    event Registered(address indexed, RegisterParams);
}
