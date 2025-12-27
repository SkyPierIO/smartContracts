// contracts/internal/tokens/AdminBadge.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract AdminBadge is ERC721, AccessControl {
    uint256 private _tokenIdCounter;

    constructor() ERC721("Skypier Admin Badge", "SAB") {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /**
     * @dev Mints admin badge to an address
     * @param to Address to receive the badge
     */
    function mintAdminBadge(address to) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Not authorized");
        uint256 tokenId = _tokenIdCounter;
        _tokenIdCounter++;
        _safeMint(to, tokenId);
        grantRole(DEFAULT_ADMIN_ROLE, to);
    }

    /**
     * @dev Burns admin badge from an address
     * @param tokenId ID of the badge to burn
     */
    function burnAdminBadge(uint256 tokenId) external {
        address owner = ownerOf(tokenId);
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Not authorized");
        _burn(tokenId);
        revokeRole(DEFAULT_ADMIN_ROLE, owner);
    }

    /**
     * @dev Override transfer to enforce soulbound behavior
     */
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