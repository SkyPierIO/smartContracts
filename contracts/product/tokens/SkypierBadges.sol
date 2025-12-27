// contracts/product/tokens/SkypierBadges.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
// The purpose of this contract is to assign ERC1155 SkypierBadge to our users

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";

contract SkypierBadges is ERC1155, AccessControl, ERC165 {
    // Badge IDs
    uint256 public constant CLIENT_BADGE = 0;
    uint256 public constant OPERATOR_BADGE = 1;
    uint256 public constant VALIDATOR_BADGE = 2;
    uint256 public constant BETA_TESTER_BADGE = 3;

    constructor() ERC1155("https://skypier.io/badges/{id}.json") {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    // function initialize() public initializer {
    //     __ERC1155_init("https://api.skypier.com/metadata/{id}.json");
    // }

    function mintClientBadge(address to) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Not authorized");
        _mint(to, CLIENT_BADGE, 1, "");
    }

    function mintOperatorBadge(address to, string memory peerId) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Not authorized");
        _mint(to, OPERATOR_BADGE, 1, abi.encodePacked(peerId));
    }

    function mintValidatorBadge(address to) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Not authorized");
        _mint(to, VALIDATOR_BADGE, 1, "");
    }

    function mintBetaTesterBadge(address to) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Not authorized");
        _mint(to, BETA_TESTER_BADGE, 1, "");
    }
}