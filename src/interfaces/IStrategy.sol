// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IStrategy {
    function claim(uint256 revenueAmount, bytes calldata data) external;
}
