// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {ERC1155Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";

import {CLIENT_TOKEN_ID, IClientToken} from "./interfaces/IClientToken.sol";
import {Roles} from "./lib/Roles.sol";
import {ClientTokenStorage} from "./lib/storage/ClientTokenStorage.sol";

/// @title ClientToken
/// @notice ERC-1155 token that proves a client has paid for Skypier VPN access. Id 1 is the Client token; id 2 is
/// reserved for the Beta Tester badge and can't be minted in the Core MVP.
/// @dev UUPS upgradeable. All of this contract's own state lives in the ERC-7201 namespace of {ClientTokenStorage};
/// ERC-1155 balances, the URI and roles live in OpenZeppelin's namespaces.
///
/// Rules this implementation keeps on every path:
/// - A wallet holds at most one token per id.
/// - A wallet with no token has expiry 0, and a wallet with a token has a non-zero expiry. {isValid} relies on this
///   to read only the expiry. Any upgrade must keep it.
/// - State is written and events emitted before a mint or transfer calls the receiver's `onERC1155Received`, and
///   the three state-changing functions are `nonReentrant`.
/// - The IClientToken functions revert with {UnsupportedId} for any id other than {CLIENT_TOKEN_ID}; {isValid}
///   returns false instead. ERC-1155's own `balanceOf`, `balanceOfBatch` and `uri` don't revert for other ids.
contract ClientToken is
    IClientToken,
    ERC1155Upgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable,
    ReentrancyGuardTransient
{
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Sets up the proxy: the admin Safe gets DEFAULT_ADMIN_ROLE and UPGRADER_ROLE.
    /// @dev MINTER_ROLE is granted later by the Safe, to PaymentPool, once PaymentPool is deployed. Reverts with
    /// {ZeroAddress} if `admin` is zero. Emits ERC-1155's URI event for {CLIENT_TOKEN_ID}, and AccessControl's
    /// RoleGranted events.
    /// @param admin The admin Safe.
    /// @param uri_ The ERC-1155 metadata URI, with `{id}` substitution; may be empty.
    function initialize(address admin, string calldata uri_) external initializer {
        if (admin == address(0)) revert ZeroAddress();
        __ERC1155_init(uri_);
        __AccessControl_init();
        _grantRole(Roles.DEFAULT_ADMIN_ROLE, admin);
        _grantRole(Roles.UPGRADER_ROLE, admin);
        emit URI(uri_, CLIENT_TOKEN_ID);
    }

    // ------------------------------------------------------------------ IClientToken: state-changing

    /// @inheritdoc IClientToken
    function extendAccess(address account, uint256 id, uint48 duration)
        external
        onlyRole(Roles.MINTER_ROLE)
        nonReentrant
        returns (uint48 newExpiry)
    {
        _requireSupported(id);
        if (account == address(0)) revert ZeroAddress();
        if (duration == 0) revert ZeroDuration();

        ClientTokenStorage.Layout storage l = ClientTokenStorage.layout();
        newExpiry = _addToLater(l.expiry[account][id], duration);
        bool mints = balanceOf(account, id) == 0;

        // Effects and our own event first: minting calls the receiver after updating the balance.
        l.expiry[account][id] = newExpiry;
        emit AccessExtended(account, id, newExpiry);
        if (mints) _mint(account, id, 1, "");
    }

    /// @inheritdoc IClientToken
    function burnClientToken() external nonReentrant {
        address account = _msgSender();
        if (balanceOf(account, CLIENT_TOKEN_ID) == 0) revert NoAccess(account, CLIENT_TOKEN_ID);

        ClientTokenStorage.layout().expiry[account][CLIENT_TOKEN_ID] = 0;
        emit AccessBurned(account, CLIENT_TOKEN_ID);
        _burn(account, CLIENT_TOKEN_ID, 1);
    }

    /// @inheritdoc IClientToken
    /// @dev When `to` has no token, `from`'s token moves to it in one ERC-1155 transfer (TransferSingle from
    /// `from` to `to`). When `to` already has one, `from`'s token is burned (TransferSingle from `from` to zero).
    function adminTransfer(address from, address to, uint256 id)
        external
        onlyRole(Roles.DEFAULT_ADMIN_ROLE)
        nonReentrant
        returns (uint48 newExpiry)
    {
        _requireSupported(id);
        if (to == address(0)) revert ZeroAddress();
        if (to == from) revert SameAccount(from);

        ClientTokenStorage.Layout storage l = ClientTokenStorage.layout();
        uint48 fromExpiry = l.expiry[from][id];
        if (balanceOf(from, id) == 0 || fromExpiry <= block.timestamp) revert NoAccess(from, id);

        // fromExpiry > block.timestamp, and fromExpiry fits in a uint48, so neither the cast nor the subtraction
        // can fail.
        uint48 remaining = fromExpiry - uint48(block.timestamp);
        newExpiry = _addToLater(l.expiry[to][id], remaining);
        bool receiverHasToken = balanceOf(to, id) != 0;

        l.expiry[from][id] = 0;
        l.expiry[to][id] = newExpiry;
        emit AccessTransferred(from, to, id, newExpiry);
        if (receiverHasToken) {
            _burn(from, id, 1);
        } else {
            _safeTransferFrom(from, to, id, 1, "");
        }
    }

    /// @inheritdoc IClientToken
    function setURI(string calldata newUri) external onlyRole(Roles.DEFAULT_ADMIN_ROLE) {
        _setURI(newUri);
        emit URI(newUri, CLIENT_TOKEN_ID);
    }

    // ------------------------------------------------------------------ IClientToken: views

    /// @inheritdoc IClientToken
    /// @dev One storage read: a wallet with no token always has expiry 0 (see the contract notes).
    function isValid(address account, uint256 id) external view returns (bool) {
        if (id != CLIENT_TOKEN_ID) return false;
        return ClientTokenStorage.layout().expiry[account][id] > block.timestamp;
    }

    /// @inheritdoc IClientToken
    function expiryOf(address account, uint256 id) external view returns (uint48) {
        _requireSupported(id);
        return ClientTokenStorage.layout().expiry[account][id];
    }

    // ------------------------------------------------------------------ ERC-1155: transfers disabled

    /// @notice Always reverts with {TransfersDisabled}: Client tokens can't be approved or traded.
    function setApprovalForAll(address, bool) public pure override {
        revert TransfersDisabled();
    }

    /// @notice Always reverts with {TransfersDisabled}. Only the admin Safe moves a token, with {adminTransfer}.
    function safeTransferFrom(address, address, uint256, uint256, bytes memory) public pure override {
        revert TransfersDisabled();
    }

    /// @notice Always reverts with {TransfersDisabled}. Only the admin Safe moves a token, with {adminTransfer}.
    function safeBatchTransferFrom(address, address, uint256[] memory, uint256[] memory, bytes memory)
        public
        pure
        override
    {
        revert TransfersDisabled();
    }

    // ------------------------------------------------------------------ ERC-165

    /// @notice ERC-165: ERC-1155, ERC-1155 metadata, AccessControl and IClientToken.
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC1155Upgradeable, AccessControlUpgradeable)
        returns (bool)
    {
        return interfaceId == type(IClientToken).interfaceId || super.supportsInterface(interfaceId);
    }

    // ------------------------------------------------------------------ internal

    /// @dev Only UPGRADER_ROLE (the admin Safe) can upgrade.
    function _authorizeUpgrade(address) internal override onlyRole(Roles.UPGRADER_ROLE) {}

    /// @dev The later of now and `current`, plus `duration`. Reverts with {ExpiryOverflow} past uint48.
    function _addToLater(uint48 current, uint48 duration) private view returns (uint48) {
        uint256 start = current > block.timestamp ? current : block.timestamp;
        uint256 end = start + duration;
        if (end > type(uint48).max) revert ExpiryOverflow();
        return uint48(end);
    }

    /// @dev Reverts with {UnsupportedId} unless `id` is {CLIENT_TOKEN_ID}.
    function _requireSupported(uint256 id) private pure {
        if (id != CLIENT_TOKEN_ID) revert UnsupportedId(id);
    }
}
