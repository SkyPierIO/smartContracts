// contracts/internal/tokens/BuilderToken.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract BuilderToken is ERC1155, AccessControl {
    uint256 public constant BUILDER_BADGE = 0;
    uint256 public constant QA_BADGE = 1;
    uint256 public constant DEVELOPER_BADGE = 2;
    uint256 public constant WALLET_CAP = 6;

    constructor() ERC1155("https://skypier.io/builder/{id}.json") {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function mintBuilderToken(address to) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Not authorized");
        _mint(to, BUILDER_BADGE, 1, "");
        _mint(to, QA_BADGE, 1, "");
    }

    function mintDeveloperBadge(address to) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Not authorized");
        _mint(to, DEVELOPER_BADGE, 1, "");
    }
}