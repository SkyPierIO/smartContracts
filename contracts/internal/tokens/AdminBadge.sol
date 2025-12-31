// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {ERC1155Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract AdminBadge is ERC721, AccessControlUpgradeable, ReentrancyGuard {
    uint256 private _tokenIdCounter;
    IERC1155 public immutable builderToken; 
    uint256 public immutable builderTokenId; 

    event RoleGranted(address indexed account, bytes32 indexed role);
    event RoleRevoked(address indexed account, bytes32 indexed role);

    constructor(address _builderToken, uint256 _builderTokenId) 
        ERC721("Skypier Admin Badge", "SAB") 
    {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        builderToken = IERC1155(_builderToken);
        builderTokenId = _builderTokenId;
    }

    modifier onlyBuilderTokenHolder() {
        require(
            builderToken.balanceOf(msg.sender, builderTokenId) > 0,  // <-- Check ERC1155 balance
            "Must hold Builder Token"
        );
        _;
    }

    function mintAdminBadge(address to)
        external
        onlyBuilderTokenHolder
        onlyRole(DEFAULT_ADMIN_ROLE)
        nonReentrant
    {
        require(to != address(0), "Cannot mint to zero address");
        uint256 tokenId = _tokenIdCounter++;
        _safeMint(to, tokenId);
        grantRole(DEFAULT_ADMIN_ROLE, to);
        emit RoleGranted(to, DEFAULT_ADMIN_ROLE);
    }

    function burnAdminBadge(uint256 tokenId)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
        nonReentrant
    {
        address owner = ownerOf(tokenId);
        _burn(tokenId);
        revokeRole(DEFAULT_ADMIN_ROLE, owner);
        emit RoleRevoked(owner, DEFAULT_ADMIN_ROLE);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override {
        super._beforeTokenTransfer(from, to, tokenId);
        if (from != address(0)) {
            require(to == address(0) || to == from, "Admin badge is soulbound");
        }
    }
}