// contracts/product/tokens/SkypierBadges.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {ERC1155Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
// import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "../../interfaces/IERC6551Registry.sol";
import "../../interfaces/ITokenBoundAccount.sol";

contract SkypierBadges is ERC1155Upgradeable, AccessControl, ERC165 {
    // Badge IDs
    uint256 public constant CLIENT_BADGE = 0;
    uint256 public constant OPERATOR_BADGE = 1;
    uint256 public constant VALIDATOR_BADGE = 2;
    uint256 public constant BETA_TESTER_BADGE = 3;

    // ERC6551 Registry
    IERC6551Registry public erc6551Registry;
    address public tokenBoundAccountImplementation;

    // Events
    event TokenBoundAccountCreated(
        address indexed tokenContract,
        uint256 indexed tokenId,
        address indexed account,
        address owner
    );

    constructor(address _erc6551Registry, address _tokenBoundAccountImplementation)
        ERC1155("https://skypier.io/badges/{id}.json")
    {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        erc6551Registry = IERC6551Registry(_erc6551Registry);
        tokenBoundAccountImplementation = _tokenBoundAccountImplementation;
    }

    /**
     * @dev Mints a client badge and creates a TokenBoundAccount
     * @param to Address to receive the badge
     */
    function mintClientBadge(address to) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Not authorized");
        _mintWithAccount(to, CLIENT_BADGE, "");
    }

    /**
     * @dev Mints an operator badge with PeerID and creates a TokenBoundAccount
     * @param to Address to receive the badge
     * @param peerId PeerID of the operator node
     */
    function mintOperatorBadge(address to, string memory peerId) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Not authorized");
        _mintWithAccount(to, OPERATOR_BADGE, peerId);
    }

    /**
     * @dev Mints a validator badge and creates a TokenBoundAccount
     * @param to Address to receive the badge
     */
    function mintValidatorBadge(address to) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Not authorized");
        _mintWithAccount(to, VALIDATOR_BADGE, "");
    }

    /**
     * @dev Mints a beta tester badge and creates a TokenBoundAccount
     * @param to Address to receive the badge
     */
    function mintBetaTesterBadge(address to) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Not authorized");
        _mintWithAccount(to, BETA_TESTER_BADGE, "");
    }

    /**
     * @dev Internal function to mint a badge and create a TokenBoundAccount
     * @param to Address to receive the badge
     * @param badgeId ID of the badge to mint
     * @param data Additional data for the badge
     */
    function _mintWithAccount(address to, uint256 badgeId, string memory data) internal {
        uint256 tokenId = _nextTokenId();
        _mint(to, tokenId, 1, data);

        // Create TokenBoundAccount for this badge
        address account = erc6551Registry.createAccount(
            tokenBoundAccountImplementation,
            block.chainid,
            address(this),
            tokenId,
            0 // salt
        );

        emit TokenBoundAccountCreated(address(this), tokenId, account, to);
    }

    /**
     * @dev Gets the TokenBoundAccount for a badge
     * @param tokenId ID of the token
     * @return address TokenBoundAccount address
     */
    function getTokenBoundAccount(uint256 tokenId) external view returns (address) {
        return erc6551Registry.account(
            tokenBoundAccountImplementation,
            block.chainid,
            address(this),
            tokenId,
            0 // salt
        );
    }

    /**
     * @dev Override supportsInterface to include ERC6551 interfaces
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return
            interfaceId == type(IERC6551Registry).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**
     * @dev Gets the PeerID for an operator badge
     * @param tokenId ID of the operator badge
     * @return string PeerID
     */
    function getOperatorPeerId(uint256 tokenId) external view returns (string memory) {
        require(_exists(tokenId), "Token does not exist");
        require(_getBadgeType(tokenId) == OPERATOR_BADGE, "Not an operator badge");

        bytes memory data = _tokenData[tokenId];
        return abi.decode(data, (string));
    }

    /**
     * @dev Internal helper to get the badge type from a token ID
     */
    function _getBadgeType(uint256 tokenId) internal view returns (uint256) {
        // In a real implementation, you would need to track which badge type each token ID belongs to
        // This is a simplified version that assumes the first token of each type has a specific ID range
        if (tokenId <= 10000) return CLIENT_BADGE;
        else if (tokenId <= 20000) return OPERATOR_BADGE;
        else if (tokenId <= 30000) return VALIDATOR_BADGE;
        else return BETA_TESTER_BADGE;
    }

    /**
     * @dev Internal helper to check if a token exists
     */
    function _exists(uint256 tokenId) internal view returns (bool) {
        return _tokenOwners[tokenId] != address(0);
    }

    /**
     * @dev Override _beforeTokenTransfer to add custom logic
     */
    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual override {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);

        // For BETA_TESTER_BADGE, require multisig approval
        for (uint256 i = 0; i < ids.length; i++) {
            if (_getBadgeType(ids[i]) == BETA_TESTER_BADGE) {
                // In a real implementation, you would check for multisig approval here
                require(hasRole(DEFAULT_ADMIN_ROLE, operator), "Multisig required for Beta Tester Badge transfer");
            }
        }
    }
}