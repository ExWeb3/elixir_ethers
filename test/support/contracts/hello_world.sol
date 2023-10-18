// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract HelloWorld {
    string str = "Hello World!";

    function sayHello() public view returns (string memory) {
        return str;
    }

    function setHello(string calldata message) external {
        emit HelloSet(message);
        str = message;
    }

    event HelloSet(string message);
}
