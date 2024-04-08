// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

error BadClaim();
error BadModule();
error InputIsZero();
error ZeroAddress();
error Unauthorized();

interface IProtocol {
    event Revenue(
        uint256 indexed tokenId, uint256 indexed amount, uint256 indexed tariff, address from, uint256 timestamp
    );

    event Claim(address indexed to, uint256 indexed amount, uint256 indexed timestamp);

    function _curateModule(address CLMAddress, bool state) external;

    function _setFeeAddress(address otherAddress) external;

    function _setContractId(uint256 tokenId, string memory contractId) external;

    function _setTariff(uint256 tokenId, uint256 tariff) external;

    function pay(uint256 tokenId) external payable;

    function claim(address CLMAddress, bytes calldata data) external;

    function tariffOf(uint256 tokenId) external view returns (uint256);
}
