// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {UD60x18} from "@prb/math@4.0.2/src/UD60x18.sol";

error BadStrategy();
error InputIsZero();
error ZeroAddress();
error Unauthorized();
error TransferError();

interface IProtocol {
    event Switch(uint256 indexed tokenId, bool indexed state, uint256 indexed timestamp, address from);

    event Revenue(
        uint256 indexed tokenId, uint256 indexed amount, UD60x18 indexed taffif, address from, uint256 timestamp
    );

    event Claim(address indexed to, uint256 indexed amount, uint256 indexed timestamp);

    function _curateStrategy(address strategyAddress, bool state) external;

    function _setFeeAddress(address otherAddress) external;

    function _setTariff(uint256 tokenId, UD60x18 tariff) external;

    function pay(uint256 tokenId, uint256 amount) external;

    function claim(address strategyAddress, bytes calldata data) external;

    function tariffOf(uint256 tokenId) external view returns (UD60x18);
}
