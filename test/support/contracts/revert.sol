// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract Revert {
    function get(bool success) public pure returns (bool) {
        require(success, "success must be true");
        return true;
    }

    function reverting() public pure {
        revert("revert message");
    }

    error RevertError();
    error RevertWithMessage(string message);
    error RevertWithUnnamedArg(uint8);

    function revertingWithError() public pure {
        revert RevertError();
    }

    function revertingWithMessage() public pure {
        revert RevertWithMessage("this is sad!");
    }
}
