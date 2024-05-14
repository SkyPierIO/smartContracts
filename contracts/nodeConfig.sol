// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract NodeConfigContract is ERC721 {
    mapping(uint256 => string) public nodeConfig; // Mapping to store the latest config of node

    constructor(
        string memory name,
        string memory symbol
    ) ERC721(name, symbol) {}

    function updateNodeConfig(
        uint256 tokenId,
        string memory newConfig
    ) external {
        require(ownerOf(tokenId) == msg.sender, "Caller is not owner");

        nodeConfig[tokenId] = newConfig;
        emit NodeConfigUpdated(tokenId, newConfig);
    }

    event NodeConfigUpdated(uint256 indexed tokenId, string newConfig);
}
