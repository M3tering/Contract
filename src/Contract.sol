// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./interfaces/ICLM.sol";
import "./interfaces/IContract.sol";
import {Pausable} from "@openzeppelin/contracts@5.0.2/utils/Pausable.sol";
import {IERC721} from "@openzeppelin/contracts@5.0.2/interfaces/IERC721.sol";
import {AccessControl} from "@openzeppelin/contracts@5.0.2/access/AccessControl.sol";

/// @custom:security-contact info@whynotswitch.com
contract Contract is IContract, Pausable, AccessControl {
    mapping(address => bool) public modules;
    mapping(uint256 => Tariff) public tariffs;
    mapping(uint256 => string) public contractByM3ter;
    mapping(string => uint256) public m3terByContract;
    mapping(address => uint256) public revenues;
    mapping(uint256 => uint256) public tally;

    bytes32 public constant PAUSER = keccak256("PAUSER");
    bytes32 public constant CURATOR = keccak256("CURATOR");

    address public constant M3TER = 0x39fb420Bd583cCC8Afd1A1eAce2907fe300ABD02; //Todo: set actual contract address
    address public feeAddress;

    constructor() {
        if (address(M3TER) == address(0)) revert ZeroAddress();
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(CURATOR, msg.sender);
        _grantRole(PAUSER, msg.sender);
        feeAddress = msg.sender;
    }

    function _curateModule(address moduleAddress, bool state) external onlyRole(CURATOR) {
        modules[moduleAddress] = state;
    }

    function _setFeeAddress(address otherAddress) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (otherAddress == address(0)) revert ZeroAddress();
        feeAddress = otherAddress;
    }

    function _setTariff(
        uint256 tokenId,
        uint256 current,
        uint256 escalator,
        uint256 interval,
        string calldata contractId
    ) external {
        if (current == 0) revert InputIsZero();
        if (msg.sender != m3terOwner(tokenId)) revert Unauthorized();

        Tariff storage tariff = tariffs[tokenId];
        if (tariff.lastCheckpoint == 0) revert TariffExits();
        tariffs[tokenId] = Tariff(current, escalator, interval, block.number);
        m3terByContract[contractId] = tokenId;
    }

    function pay(uint256 tokenId) external payable whenNotPaused {
        uint256 fee = (msg.value * 3) / 1000;
        revenues[feeAddress] += fee;
        revenues[m3terOwner(tokenId)] += msg.value - fee;

        Tariff storage tariff = tariffs[tokenId];
        if (tariff.blockInterval != 0 && tariff.escalator != 0) tryEscalateTariff(tariff);
        tally[tokenId] += tariff.current * msg.value;
        emit Payment(tokenId, msg.sender, msg.value, tariff.current, tally[tokenId], block.timestamp);
    }

    function claim(address moduleAddress, bytes calldata data) external whenNotPaused {
        if (modules[moduleAddress] == false) revert BadModule();
        uint256 revenueAmount = revenues[msg.sender];
        if (revenueAmount < 1) revert InputIsZero();
        revenues[msg.sender] = 0;

        uint256 initialBalance = address(this).balance;
        ICLM(moduleAddress).claim{value: revenueAmount}(data);
        if (address(this).balance != initialBalance - revenueAmount) revert BadClaim();
        emit Claim(msg.sender, moduleAddress, revenueAmount, block.timestamp);
    }

    function pause() public onlyRole(PAUSER) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER) {
        _unpause();
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

    function tryEscalateTariff(Tariff storage tariff) internal {
        if (block.number > tariff.lastCheckpoint + tariff.blockInterval) {
            tariff.current += tariff.current * tariff.escalator / 100e18;
            tariff.lastCheckpoint += tariff.blockInterval;
            tryEscalateTariff(tariff);
        }
    }
}
