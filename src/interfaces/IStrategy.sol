// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IStrategy {
    function claim(bytes calldata data) payable external;
}
