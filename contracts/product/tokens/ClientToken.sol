// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ERC1155Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {ExpiryManagement} from "../../lib/ExpiryManagement.sol";
import {IClientToken} from "../../interfaces/IClientToken.sol";

/**
 * @title ClientToken
 * @dev ERC-1155 Soulbound Tokens for Skypier VPN clients with UUPS upgrade capability
 */
contract ClientToken is
    Initializable,
    ERC1155Upgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable,
    IERC2981,
    IClientToken
{
    using Strings for uint256;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    uint256 public constant CLIENT_BADGE = 0;
    uint256 public constant BETA_TESTER_BADGE = 1;

    using ExpiryManagement for ExpiryManagement.ExpiryInfo;
    mapping(uint256 => ExpiryManagement.ExpiryInfo) private expiries;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _minter, address _admin) public initializer {
        __ERC1155_init("https://skypier.io/metadata/{id}");
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, _minter);
        _grantRole(BURNER_ROLE, _admin);
    }

    function mint(
        address to,
        uint256 tokenId,
        uint256 amount,
        string memory metadata
    ) external override onlyRole(MINTER_ROLE) {
        require(to != address(0), "Invalid recipient");
        _mint(to, tokenId, amount, "");
        emit BadgeIssued(to, tokenId, amount, metadata);
    }

    function burn(
        address from,
        uint256 tokenId,
        uint256 amount
    ) external override onlyRole(BURNER_ROLE) {
        _burn(from, tokenId, amount);
        emit BadgeRevoked(from, tokenId, amount);
    }

    function setExpiry(uint256 tokenId, uint64 expiryTime) external onlyRole(DEFAULT_ADMIN_ROLE) {
        expiries[tokenId].setExpiryAbsolute(expiryTime);
    }

    function isExpired(uint256 tokenId) public view returns (bool) {
        return expiries[tokenId].isExpired();
    }

    function timeRemaining(uint256 tokenId) public view returns (uint256) {
        return expiries[tokenId].getTimeRemaining();
    }

    function isValidHolder(address user, uint256 tokenId) external view override returns (bool) {
        if (balanceOf(user, tokenId) == 0) return false;
        return !expiries[tokenId].isActive || expiries[tokenId].isValid();
    }

    function getExpiry(uint256 tokenId) external view override returns (uint64) {
        return expiries[tokenId].expiryTime;
    }

    function _update(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values
    ) internal override {
        require(from == address(0) || to == address(0), "Client token is soulbound");
        super._update(from, to, ids, values);
    }

    function royaltyInfo(uint256 /*tokenId*/, uint256 /*salePrice*/)
        external
        pure
        override
        returns (address receiver, uint256 royaltyAmount)
    {
        return (address(0), 0);
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyRole(DEFAULT_ADMIN_ROLE)
    {}

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC1155Upgradeable, AccessControlUpgradeable, IERC165)
        returns (bool)
    {
        return interfaceId == type(IERC2981).interfaceId || super.supportsInterface(interfaceId);
    }
}