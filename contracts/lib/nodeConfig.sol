// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract NodeConfigContract is Initializable, ERC721Upgradeable, UUPSUpgradeable, OwnableUpgradeable {
    mapping(uint256 => string) public nodeConfig; // Mapping to store the latest config of node

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(string memory name, string memory symbol) public initializer {
        __ERC721_init(name, symbol);
        __UUPSUpgradeable_init();
        __Ownable_init(msg.sender);
    }

    function updateNodeConfig(uint256 tokenId, string memory newConfig) external {
        require(ownerOf(tokenId) == msg.sender, "Caller is not owner");

        nodeConfig[tokenId] = newConfig;
        emit NodeConfigUpdated(tokenId, newConfig);
    }

    event NodeConfigUpdated(uint256 indexed tokenId, string newConfig);

    function _authorizeUpgrade(address) internal override onlyOwner {}
}
