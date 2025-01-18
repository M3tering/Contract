// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ICLM} from "./interfaces/ICLM.sol";
import {IContract} from "./interfaces/IContract.sol";
import {IERC6551Registry} from "./interfaces/IERC6551Registry.sol";
import {Pausable} from "@openzeppelin/contracts@5.0.2/utils/Pausable.sol";
import {IERC20} from "@openzeppelin/contracts@5.0.2/interfaces/IERC20.sol";
import {AccessControl} from "@openzeppelin/contracts@5.0.2/access/AccessControl.sol";

/// @custom:security-contact info@whynotswitch.com
contract Contract is IContract, Pausable, AccessControl {
    address public immutable revenueAsset;
    bytes32 public constant PAUSER = keccak256("PAUSER");
    bytes32 public constant CURATOR = keccak256("CURATOR");

    mapping(address => uint256) public revenues;
    mapping(address => bool) public modules;
    address public feeAddress;

    constructor(address asset, address defaultAdmin) {
        if (asset == address(0) || defaultAdmin == address(0)) revert CannotBeZero();
        (revenueAsset, feeAddress) = (asset, defaultAdmin);
        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(CURATOR, defaultAdmin);
        _grantRole(PAUSER, defaultAdmin);
    }

    function _curateModule(address moduleAddress, bool state) external onlyRole(CURATOR) {
        modules[moduleAddress] = state;
    }

    function _setFeeAddress(address otherAddress) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (otherAddress == address(0)) revert CannotBeZero();
        feeAddress = otherAddress;
    }

    function claim(address moduleAddress, bytes calldata data) external whenNotPaused {
        uint256 revenueAmount = revenues[msg.sender];
        if (revenueAmount == 0) revert CannotBeZero();
        if (modules[moduleAddress] == false) revert BadModule();
        revenues[msg.sender] = 0;

        uint256 initialBalance = address(this).balance;
        ICLM(moduleAddress).claim{value: revenueAmount}(data);
        if (address(this).balance != initialBalance - revenueAmount) revert BadClaim();
        emit Claim(msg.sender, moduleAddress, revenueAmount, block.timestamp);
    }

    function pay(uint256 tokenId, uint256 amount) external whenNotPaused {
        if (!IERC20(revenueAsset).transferFrom(msg.sender, address(this), amount)) revert TransferError();
        uint256 fee = (amount * 3) / 1000;
        revenues[feeAddress] += fee;
        revenues[m3terAccount(tokenId)] += amount - fee;
        emit Payment(tokenId, msg.sender, amount, block.timestamp);
    }

    function pause() public onlyRole(PAUSER) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER) {
        _unpause();
    }

    function m3terAccount(uint256 tokenId) public view returns (address) {
        address m3ter = 0x39fb420Bd583cCC8Afd1A1eAce2907fe300ABD02; // ToDo: Set actual contract address
        address registry = 0x000000006551c19487814612e58FE06813775758; // ERC6551 Registry contract @ v0.3.1
        address proxyImp = 0x55266d75D1a14E4572138116aF39863Ed6596E7F; // ERC6551 Implementation Proxy @ v0.3.1

        return IERC6551Registry(registry).account(proxyImp, 0x0, 1, m3ter, tokenId);
    }
}
