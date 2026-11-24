// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @dev ERC-1155 id of the Client token: paid access to the VPN.
uint256 constant CLIENT_TOKEN_ID = 1;

/// @dev ERC-1155 id reserved for the Beta Tester badge (Phase 2). Nothing can mint it in the Core MVP.
uint256 constant BETA_TESTER_BADGE_ID = 2;

/// @title IClientToken
/// @notice Skypier-specific functions of ClientToken, the ERC-1155 contract that proves a client has paid.
/// @dev ClientToken also implements ERC-1155 and AccessControl; their functions are not repeated here.
///
/// Rules:
/// - Expiry is stored per wallet and per token id as a uint48 Unix timestamp.
/// - A wallet holds at most one Client token. An expired token keeps its balance of 1; use {isValid}, never
///   the balance, to decide access.
/// - Ordinary ERC-1155 transfers and approvals always revert with {TransfersDisabled}. Only the admin Safe
///   moves a token, through {adminTransfer}.
/// - In the Core MVP only {CLIENT_TOKEN_ID} is supported. Every function given another id reverts with
///   {UnsupportedId}, and {isValid} returns false for it.
interface IClientToken {
    /// @notice A Client token was minted or extended.
    /// @param account The wallet whose access changed.
    /// @param id The token id.
    /// @param newExpiry The wallet's expiry after the change.
    event AccessExtended(address indexed account, uint256 indexed id, uint48 newExpiry);

    /// @notice The admin Safe moved a token and its remaining paid time to another wallet.
    /// @param from The wallet that lost access. Its expiry is now 0.
    /// @param to The wallet that received the token and the remaining time.
    /// @param id The token id.
    /// @param newExpiry The receiving wallet's expiry after the move.
    event AccessTransferred(address indexed from, address indexed to, uint256 indexed id, uint48 newExpiry);

    /// @notice A holder burned their token. Any remaining paid time is lost; there is no refund.
    /// @param account The wallet that burned its token.
    /// @param id The token id.
    event AccessBurned(address indexed account, uint256 indexed id);

    /// @notice The id is not supported in the Core MVP.
    error UnsupportedId(uint256 id);

    /// @notice Ordinary ERC-1155 transfers and approvals are disabled.
    error TransfersDisabled();

    /// @notice An extension must add a positive duration.
    error ZeroDuration();

    /// @notice An address argument was the zero address.
    error ZeroAddress();

    /// @notice The wallet has no token, or no paid time left, to burn or move.
    error NoAccess(address account, uint256 id);

    /// @notice {adminTransfer} was given the same wallet as source and destination.
    error SameAccount(address account);

    /// @notice The new expiry would not fit in a uint48.
    error ExpiryOverflow();

    /// @notice Mints a token if the wallet has none, then extends its expiry.
    /// @dev Only MINTER_ROLE (the PaymentPool contract). The new expiry is the later of now and the current
    /// expiry, plus `duration`. Minting runs the ERC-1155 receiver check when `account` is a contract.
    /// The 13-unit cap on how far ahead access can be bought is enforced by PaymentPool, not here.
    /// Emits {AccessExtended}, and ERC-1155's TransferSingle when a token is minted.
    /// @param account The wallet to mint for or extend.
    /// @param id Must be {CLIENT_TOKEN_ID}.
    /// @param duration Seconds of access to add; must be positive.
    /// @return newExpiry The wallet's expiry after the extension.
    function extendAccess(address account, uint256 id, uint48 duration) external returns (uint48 newExpiry);

    /// @notice Burns the caller's Client token so they can leave. Remaining paid time is lost; no refund.
    /// @dev Reverts with {NoAccess} if the caller holds no Client token. Expired tokens can be burned.
    /// Sets the caller's expiry to 0. Emits {AccessBurned} and ERC-1155's TransferSingle.
    function burnClientToken() external;

    /// @notice Moves a token and its remaining paid time to another wallet, for example after a lost key.
    /// @dev Only DEFAULT_ADMIN_ROLE (the admin Safe). Reverts with {NoAccess} if `from` holds no token or has
    /// no paid time left. `from` ends with no token and expiry 0. `to` receives a token if it has none, and
    /// its expiry becomes the later of now and its own expiry, plus the time `from` had left. Because the
    /// Safe can do this to any wallet, it can also take anyone's access. This path ignores the 13-unit cap.
    /// Emits {AccessTransferred} and ERC-1155's TransferSingle events.
    /// @param from The wallet to take the token from.
    /// @param to The wallet to give it to; not zero and not `from`.
    /// @param id Must be {CLIENT_TOKEN_ID}.
    /// @return newExpiry The receiving wallet's expiry after the move.
    function adminTransfer(address from, address to, uint256 id) external returns (uint48 newExpiry);

    /// @notice Sets the ERC-1155 metadata URI for all ids.
    /// @dev Only DEFAULT_ADMIN_ROLE. Emits ERC-1155's URI event for {CLIENT_TOKEN_ID}.
    /// @param newUri The new URI, with `{id}` substitution as ERC-1155 describes.
    function setURI(string calldata newUri) external;

    /// @notice Whether the wallet currently has paid access. The VPN node calls this after the client
    /// signs its challenge.
    /// @param account The wallet to check.
    /// @param id The token id; only {CLIENT_TOKEN_ID} can be valid in the Core MVP.
    /// @return True if the wallet holds the token and `block.timestamp` is before its expiry.
    function isValid(address account, uint256 id) external view returns (bool);

    /// @notice The wallet's stored expiry for a token id.
    /// @param account The wallet to look up.
    /// @param id The token id.
    /// @return The Unix timestamp at which access ends; 0 if never minted, burned or moved away.
    function expiryOf(address account, uint256 id) external view returns (uint48);
}
