// contracts/internal/tokens/BuilderToken.sol
// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {ERC1155Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

contract BuilderToken is ERC1155Upgradeable, AccessControlUpgradeable {
    uint256 public constant BUILDER_BADGE = 0;
    uint256 public constant EMPLOYEE_BADGE = 1;
    uint256 public constant DEVELOPER_BADGE = 2;
    uint256 public constant WALLET_CAP = 6;

    constructor() ERC1155("https://skypier.io/builder/{id}.json") {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function mintBuilderToken(address to) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Not authorized");
        _mint(to, BUILDER_BADGE, 1, "");
    }

    function mintDeveloperBadge(address to) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Not authorized");
        _mint(to, DEVELOPER_BADGE, 1, "");
    }

    function mintEmployeeBadge(address to) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Not authorized");
        _mint(to, EMPLOYEE_BADGE, 1, "");
    }
}