// contracts/internal/tokens/InvestorToken.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract InvestorToken is ERC1155, AccessControl {
    uint256 public constant INVESTOR_BADGE = 0;

    // Events
    event InvestorAdded(address indexed investor, uint256 amount);
    event InvestorRemoved(address indexed investor);

    constructor() ERC1155("https://skypier.io/investor/{id}.json") {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /**
     * @dev Mints investor badge to an address with preapproved token amount
     * @param to Address to receive the badge
     * @param amount Preapproved token amount
     */
    function mintInvestorBadge(address to, uint256 amount) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Not authorized");
        _mint(to, INVESTOR_BADGE, 1, abi.encodePacked(amount));
        emit InvestorAdded(to, amount);
    }

    /**
     * @dev Revokes investor badge from an address
     * @param from Address to revoke badge from
     */
    function revokeInvestorBadge(address from) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Not authorized");
        _burn(from, INVESTOR_BADGE, 1);
        emit InvestorRemoved(from);
    }

    /**
     * @dev Gets the preapproved token amount for an investor
     * @param investor Address to check
     * @return amount Preapproved token amount
     */
    function getInvestorAmount(address investor) public view returns (uint256) {
        bytes memory data = _getTokenData(INVESTOR_BADGE, investor);
        return abi.decode(data, (uint256));
    }

    /**
     * @dev Internal helper to get token data
     */
    function _getTokenData(uint256 tokenId, address account)
        internal
        view
        returns (bytes memory)
    {
        uint256 index = _ownedTokens[account][tokenId].length;
        require(index > 0, "No tokens owned");
        return _tokenData[tokenId][_ownedTokens[account][tokenId][index - 1]];
    }
}