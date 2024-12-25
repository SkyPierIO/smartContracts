// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract SkypierBadge is Initializable, ERC1155Upgradeable {
    function initialize() public initializer {
        __ERC1155_init("https://api.skypier.com/metadata/{id}.json");
    }
}