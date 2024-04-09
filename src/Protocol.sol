// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./interfaces/ICLM.sol";
import "./interfaces/IProtocol.sol";
import "./interfaces/IERC6551Registry.sol";
import {Pausable} from "@openzeppelin/contracts@5.0.2/utils/Pausable.sol";
import {IERC20} from "@openzeppelin/contracts@5.0.2/interfaces/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts@5.0.2/interfaces/IERC721.sol";
import {AccessControl} from "@openzeppelin/contracts@5.0.2/access/AccessControl.sol";

/// @custom:security-contact info@whynotswitch.com
contract Protocol is IProtocol, Pausable, AccessControl {
    mapping(address => bool) public modlues;
    mapping(uint256 => uint256) public tariff;
    mapping(address => uint256) public revenues;
    mapping(uint256 => string) public contractByToken;
    mapping(string => uint256) public tokenByContract;

    uint256 public constant DEFAULT_TARIFF = 0.06e18;
    bytes32 public constant PAUSER = keccak256("PAUSER");
    bytes32 public constant CURATOR = keccak256("CURATOR");
    bytes32 public constant REGISTRAR = keccak256("REGISTRAR");
    uint256 public constant TBA_SALT = uint256(keccak256("M3TERS"));

    address public constant TBA_IMPLEMENTATION = 0xf52d861E8d057bF7685e5C9462571dFf236249cF;
    address public constant TBA_REGISTRY = 0x000000006551c19487814612e58FE06813775758;
    address public constant M3TER = 0xbCFeFea1e83060DbCEf2Ed0513755D049fDE952C; // TODO: M3ter Address
    address public feeAddress;

    constructor() {
        if (address(M3TER) == address(0)) revert ZeroAddress();
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(REGISTRAR, msg.sender);
        _grantRole(CURATOR, msg.sender);
        _grantRole(PAUSER, msg.sender);
        feeAddress = msg.sender;
    }

    function _curateModule(address moduleAddress, bool state) external onlyRole(CURATOR) {
        modlues[moduleAddress] = state;
    }

    function _setFeeAddress(address otherAddress) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (otherAddress == address(0)) revert ZeroAddress();
        feeAddress = otherAddress;
    }

    function _setContractId(uint256 tokenId, string memory contractId) external {
        if (msg.sender != m3terAccount(tokenId)) revert Unauthorized();
        contractByToken[tokenId] = contractId;
        tokenByContract[contractId] = tokenId;
    }

    function _setTariff(uint256 tokenId, uint256 newTariff) external {
        if (msg.sender != m3terAccount(tokenId)) revert Unauthorized();
        if (newTariff < 1) revert InputIsZero();
        tariff[tokenId] = newTariff;
    }

    function pay(uint256 tokenId) external payable whenNotPaused {
        uint256 fee = (msg.value * 3) / 1000;
        revenues[feeAddress] += fee;
        revenues[m3terAccount(tokenId)] += msg.value - fee;
        emit Revenue(tokenId, msg.value, tariffOf(tokenId), msg.sender, block.timestamp);
    }

    function claim(address moduleAddress, bytes calldata data) external whenNotPaused {
        if (modlues[moduleAddress] == false) revert BadModule();
        uint256 revenueAmount = revenues[msg.sender];
        if (revenueAmount < 1) revert InputIsZero();
        revenues[msg.sender] = 0;

        uint256 initialBalance = address(this).balance;
        ICLM(moduleAddress).claim{value: revenueAmount}(data);
        if (address(this).balance != initialBalance - revenueAmount) {
            revert BadClaim();
        }
        emit Claim(msg.sender, revenueAmount, block.timestamp);
    }

    function pause() public onlyRole(PAUSER) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER) {
        _unpause();
    }

    function tariffOf(uint256 tokenId) public view returns (uint256) {
        uint256 _tariff = tariff[tokenId];
        return _tariff > 0 ? _tariff : DEFAULT_TARIFF;
    }

    function m3terAccount(uint256 tokenId) public view returns (address) {
        return IERC6551Registry(ERC6551REGISTRY).account(
            ERC6551IMPLEMENTATION, block.chainid, M3TER, tokenId, M3TER_ACCOUNT_SALT
        );
    }
}
