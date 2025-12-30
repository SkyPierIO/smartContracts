// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IClientToken {
    function issueBadge(
        address to,
        uint256 tokenId,
        uint256 amount,
        uint64 expiryTimestamp
    ) external;

    uint256 CLIENT_BADGE;
}