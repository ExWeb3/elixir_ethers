// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract CcipReadTest {
    error OffchainLookup(
        address sender,
        string[] urls,
        bytes callData,
        bytes4 callbackFunction,
        bytes extraData
    );

    function getValue(uint256 value) external view returns (uint256) {
        string[] memory urls = new string[](3);
        urls[0] = "invalid://example.com/ccip/{sender}/{data}";
        urls[1] = "https://example.com/ccip/{sender}/{data}";
        urls[2] = "https://backup.example.com/ccip";

        revert OffchainLookup(
            address(this),
            urls,
            abi.encode(value),
            this.handleResponse.selector,
            bytes("testing")
        );
    }

    function handleResponse(bytes calldata response, bytes calldata extraData) 
        external 
        pure 
        returns (uint256) 
    {
        // Validate extraData
        require(keccak256(abi.encodePacked(extraData)) == keccak256(bytes("testing")));
        
        // Decode the response - in real contract you'd validate this
        return abi.decode(response, (uint256));
    }

    // Helper function to test non-CCIP functionality
    function getDirectValue() external pure returns (string memory) {
        return "direct value";
    }
} 
