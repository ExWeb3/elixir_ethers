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

    function infoMany(
        address[] calldata owners
    ) public view returns (RegisterParams[] memory) {
        RegisterParams[] memory params = new RegisterParams[](owners.length);

        for (uint256 i = 0; i < owners.length; i++)
            params[i] = registry[owners[i]];

        return params;
    }

    function infoAsTuple(
        address owner
    ) public view returns (string memory, uint8) {
        return (registry[owner].name, registry[owner].age);
    }

    event Registered(address indexed, RegisterParams);
}
