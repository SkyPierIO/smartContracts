// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/OwnableUupsUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";

/**
 * @title ClientToken
 * @dev ERC-1155 Soulbound Tokens for Skypier VPN clients.
 *      - CLIENT_ROLE (default): Granted after payment.
 *      - BETA_TESTER_BADGE: Semi-fungible, transferable via multisig (future).
 */
contract ClientToken is ERC1155, OwnableUupsUpgradeable, ERC1155Supply, IERC2981 {
    using Strings for uint256;

    // --- Events ---
    event BadgeIssued(
        address indexed account,
        uint256 indexed tokenId,
        uint256 amount,
        string metadata
    );
    event BadgeRevoked(
        address indexed account,
        uint256 indexed tokenId,
        uint256 amount
    );

    // --- Token Types ---
    uint256 public constant CLIENT_BADGE = 0;       // Default client access
    uint256 public constant BETA_TESTER_BADGE = 1; // Transferable via multisig

    // --- Roles ---
    address public minter;  // SkypierVPN contract or multisig
    address public admin;   // AdminBadge holder (for revocations)

    // --- Expiry (ERC-7818) ---
    mapping(uint256 => uint64) public expiryDates; // 0 = no expiry

    // // --- ERC-2981 Royalties ---
    // uint96 private _royaltyFee;
    // address private _royaltyRecipient;

    constructor(address _minter, address _admin)
        ERC1155("https://skypier.io/metadata/{id}")
    {
        minter = _minter;
        admin = _admin;
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
    }

    // --- Core Functions ---

    /**
     * @dev Issues a client token to a user (called by SkypierVPN).
     * @param to Recipient address.
     * @param tokenId CLIENT_ROLE or BETA_TESTER_BADGE.
     * @param amount Quantity (usually 1).
     * @param expiryTimestamp 0 for no expiry (BETA_TESTER_BADGE only).
     */
    function issueToken(
        address to,
        uint256 tokenId,
        uint256 amount,
        uint64 expiryTimestamp
    ) external {
        require(msg.sender == minter, "ClientToken: caller is not minter");
        require(tokenId == CLIENT_ROLE || tokenId == BETA_TESTER_BADGE, "Invalid tokenId");

        if (tokenId == BETA_TESTER_BADGE) {
            expiryDates[tokenId] = expiryTimestamp;
        }

        _mint(to, tokenId, amount, "");
        emit TokenIssued(to, tokenId, amount, _getMetadata(tokenId, expiryTimestamp));
    }

    /**
     * @dev Revokes a token (admin-only).
     */
    function revokeToken(
        address from,
        uint256 tokenId,
        uint256 amount
    ) external {
        require(msg.sender == admin, "ClientToken: caller is not admin");
        _burn(from, tokenId, amount);
        emit TokenRevoked(from, tokenId, amount);
    }

    // --- ERC-1155 Overrides ---
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC1155, IERC2981)
        returns (bool)
    {
        return
            super.supportsInterface(interfaceId) ||
            interfaceId == type(IERC2981).interfaceId;
    }

    // // --- ERC-2981 Royalties ---
    // function royaltyInfo(uint256 tokenId, uint256 salePrice)
    //     external
    //     view
    //     override
    //     returns (address receiver, uint256 royaltyAmount)
    // {
    //     royaltyAmount = salePrice * _royaltyFee / 10_000;
    //     receiver = _royaltyRecipient;
    // }

    // function setRoyaltyInfo(address recipient, uint96 fee)
    //     external
    //     onlyOwner
    // {
    //     _royaltyRecipient = recipient;
    //     _royaltyFee = fee;
    // }

    // --- Upgradeability ---
    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyOwner
    {}

    // --- View Functions ---
    function isValidClient(address user) public view returns (bool) {
        return balanceOf(user, CLIENT_ROLE) > 0;
    }

    function isBetaTester(address user) public view returns (bool) {
        uint256 expiry = expiryDates[BETA_TESTER_BADGE];
        return
            balanceOf(user, BETA_TESTER_BADGE) > 0 &&
            (expiry == 0 || block.timestamp < expiry);
    }

    function getExpiry(uint256 tokenId) public view returns (uint64) {
        return expiryDates[tokenId];
    }

    // --- Internal ---
    function _getMetadata(uint256 tokenId, uint64 expiry)
        internal
        pure
        returns (string memory)
    {
        if (tokenId == CLIENT_ROLE) {
            return "Skypier Client Token (No Expiry)";
        } else if (tokenId == BETA_TESTER_BADGE) {
            return
                string.concat(
                    "Skypier Beta Tester Badge (Expires: ",
                    expiry.toString(),
                    ")"
                );
        }
        return "";
    }

    // --- Access Control ---
    function setMinter(address newMinter) external onlyOwner {
        minter = newMinter;
    }

    function setAdmin(address newAdmin) external onlyOwner {
        admin = newAdmin;
    }
}