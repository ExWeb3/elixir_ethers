// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

struct StructType {
    uint256 item1;
    int256 item2;
    address item3;
}

contract Types {
    // uint
    function getUint8(uint8 inp) public pure returns (uint8) {
        return inp;
    }

    function getUint16(uint16 inp) public pure returns (uint16) {
        return inp;
    }

    function getUint32(uint32 inp) public pure returns (uint32) {
        return inp;
    }

    function getUint64(uint64 inp) public pure returns (uint64) {
        return inp;
    }

    function getUint128(uint128 inp) public pure returns (uint128) {
        return inp;
    }

    function getUint256(uint256 inp) public pure returns (uint256) {
        return inp;
    }

    // int
    function getInt8(int8 inp) public pure returns (int8) {
        return inp;
    }

    function getInt16(int16 inp) public pure returns (int16) {
        return inp;
    }

    function getInt32(int32 inp) public pure returns (int32) {
        return inp;
    }

    function getInt64(int64 inp) public pure returns (int64) {
        return inp;
    }

    function getInt128(int128 inp) public pure returns (int128) {
        return inp;
    }

    function getInt256(int256 inp) public pure returns (int256) {
        return inp;
    }

    // bool
    function getBool(bool inp) public pure returns (bool) {
        return inp;
    }

    // string
    function getString(string memory str) public pure returns (string memory) {
        return str;
    }

    // address
    function getAddress(address addr) public pure returns (address) {
        return addr;
    }

    // array
    function getInt256Array(int256[] memory arr)
        public
        pure
        returns (int256[] memory)
    {
        return arr;
    }

    // fixed array
    function getFixedUintArray(uint256[3] memory inp)
        public
        pure
        returns (uint256[3] memory)
    {
        return inp;
    }

    // struct
    function getStruct(StructType memory inp)
        public
        pure
        returns (StructType memory)
    {
        return inp;
    }

    // array of structs
    function getStructArray(StructType[] memory inp)
        public
        pure
        returns (StructType[] memory)
    {
        return inp;
    }

    // bytes
    function getBytes(bytes memory inp) public pure returns (bytes memory) {
        return inp;
    }

    function getBytes1(bytes1 inp) public pure returns (bytes1) {
        return inp;
    }

    function getBytes20(bytes20 inp) public pure returns (bytes20) {
        return inp;
    }

    function getBytes32(bytes32 inp) public pure returns (bytes32) {
        return inp;
    }

    // Not implemented yet bo Solidity
    // // ufixed
    // function getUfixed(ufixed inp) public pure returns (ufixed) {
    //     return inp;
    // }
    //
    // // fixed
    // function getFixed(fixed inp) public pure returns (fixed) {
    //     return inp;
    // }
}
