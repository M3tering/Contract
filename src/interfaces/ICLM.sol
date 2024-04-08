// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface ICLM {
    function claim(bytes calldata data) external payable;
}
