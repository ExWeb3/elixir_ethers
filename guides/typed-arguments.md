# Typed Arguments

Typed arguments help Ethers with determining the exact function to use when there are multiple overloads of
the same function with same arity.

## Problem

In solidity, contract functions (and events) can be overloaded.
This means a function with the same name can be defined with different argument types and even different arities.

### Example

```solidity
contract Overloaded {
    function transfer(uint256 amount) public pure returns (string memory) {
        ...
    }

    function transfer(int256 amount) public pure returns (string memory) {
        ...
    }
}
```

In the above contract, the function transfer is once implemented with `uint256` and another time with `int256`.

Since Elixir is dynamically typed, we need a way to specify which function we need to call in this scenario.

## Solution

Ethers provides a simple helper function called `Ethers.Types.typed/2`. This function helps you with specifying the type for your parameter. It will help Ethers to know which function to select when you want to call it.

Let's try it with the example contract above. If we assume we want to call the transfer function with `uint256` type, here is the code we need.

```elixir
defmodule Overloaded do
  use Ethers.Contract, abi: ...
end

Overloaded.transfer(Ethers.Types.typed({:uint, 256}, 100))
|> Ethers.send!(...)
```

This way we have explicitly told Ethers to use the `uint256` type for the first argument.

## Supported Types

Ethers supports all generic data types from EVM. Here is a list of them.

| Elixir Type              | Solidity Type     | Description                                         |
| ------------------------ | ----------------- | --------------------------------------------------- |
| `{:uint, bitsize}`       | `uint{bitsize}`   | unsigned integer [^1]                         |
| `{:int, bitsize}`        | `int{bitsize}`    | signed integer  [^1]                          |
| `{:bytes, size}`         | `bytes{size}`     | fixed length byte array [^2]                 | 
| `:address`               | `address`         | Ethereum wallet address                             |
| `:bool`                  | `bool`            | Boolean value                                       |
| `:string`                | `string`          | Dynamic length string                               |
| `{:array, type}`         | `T[]`             | Dynamic length array of type                        |
| `{:array, type, length}` | `T[{length}]`     | Fixed length array of type                          |
| `{:tuple, types}`        | Tuples or Structs | A tuple with types (structs in solidity are tuples) |

[^1]: For `int` and `uint` data types, the bitsize must be between 8 and 256 and also dividable to 8.
[^2]: For fixed length byte array (bytes1, bytes2, ..., bytes32) the size must be between 1 and 32.
