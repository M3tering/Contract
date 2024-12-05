// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./interfaces/ICLM.sol";
import "./interfaces/IContract.sol";
import {Pausable} from "@openzeppelin/contracts@5.0.2/utils/Pausable.sol";
import {IERC721} from "@openzeppelin/contracts@5.0.2/interfaces/IERC721.sol";
import {AccessControl} from "@openzeppelin/contracts@5.0.2/access/AccessControl.sol";

/// @custom:security-contact info@whynotswitch.com
contract Contract is IContract, Pausable, AccessControl {
    mapping(bytes32 => Tariff) public tariffs;
    mapping(bytes32 => uint256) public tally;
    mapping(bytes32 => bytes32) public registry;
    mapping(address => uint256) public revenues;
    mapping(address => bool) public modules;

    bytes32 public constant CURATOR = keccak256("CURATOR");
    bytes32 public constant PAUSER = keccak256("PAUSER");

    address public constant M3TER = 0x39fb420Bd583cCC8Afd1A1eAce2907fe300ABD02; //Todo: set actual contract address
    address public feeAddress;

    constructor() {
        if (address(M3TER) == address(0)) revert CannotBeZero();
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(CURATOR, msg.sender);
        _grantRole(PAUSER, msg.sender);
        feeAddress = msg.sender;
    }

    function _curateModule(address moduleAddress, bool state) external onlyRole(CURATOR) {
        modules[moduleAddress] = state;
    }

    function _setFeeAddress(address otherAddress) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (otherAddress == address(0)) revert CannotBeZero();
        feeAddress = otherAddress;
    }

    function setTariff(bytes32 contractId, uint256 tokenId, uint256 current, uint256 escalator, uint256 interval)
        external
    {
        if (current == 0) revert CannotBeZero();
        if (tariffs[contractId].lastCheckpoint == 0) revert TariffExits();
        tariffs[contractId] = Tariff(tokenId, current, escalator, interval, block.number);
        register(contractId, tokenId);
    }

    function claim(address moduleAddress, bytes calldata data) external whenNotPaused {
        uint256 revenueAmount = revenues[msg.sender];
        if (revenueAmount < 1) revert CannotBeZero();
        if (modules[moduleAddress] == false) revert BadModule();
        revenues[msg.sender] = 0;

        uint256 initialBalance = address(this).balance;
        ICLM(moduleAddress).claim{value: revenueAmount}(data);
        if (address(this).balance != initialBalance - revenueAmount) revert BadClaim();
        emit Claim(msg.sender, moduleAddress, revenueAmount, block.timestamp);
    }

    function pay(uint256 tokenId) external payable {
        payContract(registry[bytes32(tokenId)]);
    }

    function payContract(bytes32 contractId) public payable whenNotPaused {
        Tariff storage tariff = tariffs[contractId];
        uint256 amount = (msg.value * 997) / 1000;
        uint256 tokenId = tariff.tokenId;

        if (tariff.blockInterval != 0 && tariff.escalator != 0) tryEscalateTariff(tariff);

        revenues[m3terOwner(tokenId)] += amount;
        revenues[feeAddress] += msg.value - amount;
        tally[contractId] += tariff.current * msg.value;
        emit Payment(contractId, tokenId, msg.sender, msg.value, tariff.current, tally[contractId], block.timestamp);
    }

    function register(bytes32 contractId, uint256 tokenId) public {
        uint256 decoded = uint256(registry[contractId]);
        // reverts if registry contains value that's not attributable to sender (avoid overwrites).
        if ((msg.sender != m3terOwner(tokenId)) || (decoded != 0 && decoded != tokenId)) revert Unauthorized();
        registry[contractId] = bytes32(tokenId);
        registry[bytes32(tokenId)] = contractId;
    }

    function m3terOwner(uint256 tokenId) public view returns (address) {
        // Todo: read owner of M3ter token on the L1, possibly via L1SLOAD
        /*
        bytes32 ownerSlot = keccak256(abi.encode(tokenId, STORAGE_SLOT));
        bytes memory input = abi.encodePacked(M3TER, ownerSlot);
        (bool success, bytes memory result) = L1_SLOAD_ADDRESS.staticcall(input);
        if (!success) revert BadL1SLOAD();
        return abi.decode(result, (uint256));
        */
    }

    function pause() public onlyRole(PAUSER) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER) {
        _unpause();
    }

    function tryEscalateTariff(Tariff storage tariff) internal {
        if (block.number > tariff.lastCheckpoint + tariff.blockInterval) {
            tariff.current += tariff.current * tariff.escalator / 100e18;
            tariff.lastCheckpoint += tariff.blockInterval;
            tryEscalateTariff(tariff);
        }
    }
}
