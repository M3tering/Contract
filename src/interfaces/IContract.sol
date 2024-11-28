// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IContract {
    struct Tariff {
        uint256 current;
        uint256 escalator;
        uint256 blockInterval;
        uint256 lastCheckpoint;
    }

    event Claim(
        address indexed by,
        address indexed via,
        uint256 amount,
        uint256 timestamp
    );

    event Payment(
        uint256 indexed tokenId,
        address indexed from,
        uint256 amount,
        uint256 tariff,
        uint256 tally,
        uint256 timestamp
    );

    error BadClaim();
    error BadModule();
    error InputIsZero();
    error TariffExits();
    error ZeroAddress();
    error Unauthorized();

    function _curateModule(address CLMAddress, bool state) external;

    function _setFeeAddress(address otherAddress) external;

    function _setTariff(
        uint256 tokenId,
        uint256 current,
        uint256 escalator,
        uint256 interval,
        string calldata contractId
    ) external;

    function pay(uint256 tokenId) external payable;

    function claim(address CLMAddress, bytes calldata data) external;
}
