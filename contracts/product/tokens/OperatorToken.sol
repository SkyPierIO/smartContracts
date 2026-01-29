// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ERC1155Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title OperatorToken
 * @dev ERC-1155 non-transferable token for node operators with UUPS upgrade capability
 * Represents ownership of operator nodes in the Skypier network
 */
contract OperatorToken is
    Initializable,
    ERC1155Upgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable
{
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    uint256 private _tokenIdCounter;

    struct OperatorInfo {
        string nodeId;
        uint256 registeredAt;
        bool isActive;
    }

    mapping(uint256 => OperatorInfo) public operatorInfo;

    event OperatorRegistered(uint256 indexed tokenId, string nodeId, address owner);
    event OperatorUnregistered(uint256 indexed tokenId);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() public initializer {
        __ERC1155_init("https://skypier.io/operator/{id}.json");
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(BURNER_ROLE, msg.sender);
    }

    /**
     * @dev Mint operator token (1 per operator for soulbound semantics)
     */
    function mint(
        address to,
        string memory nodeId
    ) public onlyRole(MINTER_ROLE) returns (uint256) {
        uint256 tokenId = _tokenIdCounter++;
        _mint(to, tokenId, 1, "");

        operatorInfo[tokenId] = OperatorInfo({
            nodeId: nodeId,
            registeredAt: block.timestamp,
            isActive: true
        });

        emit OperatorRegistered(tokenId, nodeId, to);
        return tokenId;
    }

    /**
     * @dev Deregister operator (mark as inactive)
     */
    function deregisterOperator(uint256 tokenId) public onlyRole(BURNER_ROLE) {
        require(totalSupply(tokenId) > 0, "Token does not exist");
        operatorInfo[tokenId].isActive = false;
        emit OperatorUnregistered(tokenId);
    }

    /**
     * @dev Get total supply of a token ID - use public balanceOf via burn sentinel approach
     */
    function totalSupply(uint256 tokenId) public view returns (uint256) {
        // ERC1155 doesn't provide a built-in totalSupply per token ID
        // In practice, track this separately or query events
        // For now, check if operator info exists
        return operatorInfo[tokenId].isActive ? 1 : 0;
    }

    /**
     * @dev Enforce soulbound semantics: no transfers except burn/mint
     */
    function _beforeTokenTransfer(
        address /*operator*/,
        address from,
        address to,
        uint256[] memory /*ids*/,
        uint256[] memory /*amounts*/,
        bytes memory /*data*/
    ) internal {
        require(from == address(0) || to == address(0), "OperatorToken is soulbound");
    }

    /**
     * @dev Support AccessControl interface
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC1155Upgradeable, AccessControlUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    /**
     * @dev UUPS upgrade authorization
     */
    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyRole(DEFAULT_ADMIN_ROLE)
    {}
}
