// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./interfaces/IProtocol.sol";
import "./interfaces/IStrategy.sol";

import {UD60x18, ud60x18} from "@prb/math@4.0.2/src/UD60x18.sol";
import {Pausable} from "@openzeppelin/contracts@5.0.2/utils/Pausable.sol";
import {IERC20} from "@openzeppelin/contracts@5.0.2/interfaces/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts@5.0.2/interfaces/IERC721.sol";
import {AccessControl} from "@openzeppelin/contracts@5.0.2/access/AccessControl.sol";

/// @custom:security-contact info@whynotswitch.com
contract Protocol is IProtocol, Pausable, AccessControl {
    mapping(address => bool) public strategy;
    mapping(uint256 => UD60x18) public tariff;
    mapping(address => uint256) public revenues;

    IERC20 public constant SDAI = IERC20(0xaf204776c7245bF4147c2612BF6e5972Ee483701);
    IERC721 public constant M3TER = IERC721(0xbCFeFea1e83060DbCEf2Ed0513755D049fDE952C); // TODO: M3ter Address

    UD60x18 public constant DEFAULT_TARIFF = UD60x18.wrap(0.167e18);

    bytes32 public constant PAUSER = keccak256("PAUSER");
    bytes32 public constant CURATOR = keccak256("CURATOR");
    bytes32 public constant REGISTRAR = keccak256("REGISTRAR");
    address public feeAddress;

    constructor() {
        if (address(M3TER) == address(0)) revert ZeroAddress();
        if (address(SDAI) == address(0)) revert ZeroAddress();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(REGISTRAR, msg.sender);
        _grantRole(CURATOR, msg.sender);
        _grantRole(PAUSER, msg.sender);
        feeAddress = msg.sender;
    }

    function _curateStrategy(address strategyAddress, bool state) external onlyRole(CURATOR) {
        strategy[strategyAddress] = state;
    }

    function _setFeeAddress(address otherAddress) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (otherAddress == address(0)) revert ZeroAddress();
        feeAddress = otherAddress;
    }

    function _setTariff(uint256 tokenId, UD60x18 newTariff) external {
        if (msg.sender != _ownerOf(tokenId)) revert Unauthorized();
        if (newTariff < ud60x18(1)) revert InputIsZero();
        tariff[tokenId] = newTariff;
    }

    function pay(uint256 tokenId, uint256 amount) external whenNotPaused {
        if (!SDAI.transferFrom(msg.sender, address(this), amount)) revert TransferError();

        uint256 fee = (amount * 3) / 1000;
        revenues[feeAddress] += fee;
        revenues[_ownerOf(tokenId)] += amount - fee;

        emit Revenue(tokenId, amount, tariffOf(tokenId), msg.sender, block.timestamp);
    }

    function claim(address strategyAddress, bytes calldata data) external whenNotPaused {
        if (strategy[strategyAddress] == false) revert BadStrategy();
        uint256 revenueAmount = revenues[msg.sender];
        if (revenueAmount < 1) revert InputIsZero();
        uint256 preBalance = SDAI.balanceOf(address(this));
        revenues[msg.sender] = 0;

        if (!SDAI.approve(strategyAddress, revenueAmount)) revert Unauthorized();
        IStrategy(strategyAddress).claim(revenueAmount, data);

        uint256 postBalance = SDAI.balanceOf(address(this));
        if (postBalance != preBalance - revenueAmount) revert TransferError();
        emit Claim(msg.sender, revenueAmount, block.timestamp);
    }

    function pause() public onlyRole(PAUSER) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER) {
        _unpause();
    }

    function tariffOf(uint256 tokenId) public view returns (UD60x18) {
        UD60x18 _tariff = tariff[tokenId];
        return _tariff > ud60x18(0) ? _tariff : DEFAULT_TARIFF;
    }

    function _ownerOf(uint256 tokenId) internal view returns (address) {
        return M3TER.ownerOf(tokenId);
    }
}
