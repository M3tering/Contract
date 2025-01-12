// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IContract {
    event Claim(address indexed by, address indexed via, uint256 amount, uint256 timestamp);
    event Payment(uint256 indexed tokenId, address indexed from, uint256 amount, uint256 timestamp);

    error BadClaim();
    error BadModule();
    error TariffExits();
    error CannotBeZero();
    error Unauthorized();
    error TransferError();

    function _curateModule(address CLMAddress, bool state) external;

    function _setFeeAddress(address otherAddress) external;

    function claim(address CLMAddress, bytes calldata data) external;

    function pay(uint256 tokenId, uint256 amount) external;

    function m3terAccount(uint256 tokenId) external view returns (address);
}
