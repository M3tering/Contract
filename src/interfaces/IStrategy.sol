// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IStrategy {
    function claim(uint256 revenueAmount, bytes calldata data) external;
}
