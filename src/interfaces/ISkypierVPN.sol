// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @title ISkypierVPN
/// @notice The node registry: which operators may run nodes, which nodes are validated, and which count as
/// operational for payouts.
/// @dev SkypierVPN also implements AccessControl; its functions are not repeated here. The operator whitelist
/// is OPERATOR_ROLE and validators hold VALIDATOR_ROLE, both granted and revoked by the admin Safe with
/// grantRole and revokeRole.
///
/// Rules:
/// - A node is identified by `nodeId` = keccak256(peerId), where `peerId` is the libp2p PeerID in its binary
///   form (the bytes of Go's peer.ID), never its text form.
/// - One operator per PeerID, for life: once registered, no other operator can take it.
/// - Lifecycle: None -> Pending (registered) -> Validated -> Deactivated. The same operator can register a
///   Deactivated PeerID again; it goes back to Pending and needs validating again.
/// - A validator can't validate a node it operates.
/// - A node is operational while it is Validated and its operator holds OPERATOR_ROLE. Revoking the role stops
///   all of that operator's nodes at once; granting it again revives its Validated nodes.
/// - An operator's referrer is recorded once, at its first registration, and can't be the operator.
///
/// Pending item 11: `registerNode` is not declared yet. Two signatures are under review with Clement:
///   registerNode(bytes peerId, address referrer)                                  (spec as written)
///   registerNode(bytes peerId, address referrer, bytes32 pubKeyY, bytes nodeSig)  (node key signs on-chain)
/// The errors and events it needs are declared below; NodeRegistered may gain the node key's address.
interface ISkypierVPN {
    /// @notice Where a node is in its lifecycle.
    enum NodeStatus {
        None,
        Pending,
        Validated,
        Deactivated
    }

    /// @notice A registered node.
    /// @param operator The operator that registered it; never changes.
    /// @param status Where the node is in its lifecycle.
    /// @param registeredAt When it was last registered.
    /// @param validatedAt When it was last validated; 0 while Pending.
    /// @param deactivatedAt When it was last deactivated; 0 if it never was.
    /// @param validator Who last validated it; zero while Pending.
    struct Node {
        address operator;
        NodeStatus status;
        uint48 registeredAt;
        uint48 validatedAt;
        uint48 deactivatedAt;
        address validator;
    }

    /// @notice A node was registered, or registered again after deactivation.
    /// @param nodeId keccak256 of `peerId`.
    /// @param operator The registering operator.
    /// @param peerId The PeerID in binary form.
    event NodeRegistered(bytes32 indexed nodeId, address indexed operator, bytes peerId);

    /// @notice A validator validated a node. The operator's active days start with its first validated node.
    event NodeValidated(bytes32 indexed nodeId, address indexed operator, address indexed validator);

    /// @notice A node was deactivated by its operator or the admin Safe.
    /// @param by The caller: the operator or the Safe.
    event NodeDeactivated(bytes32 indexed nodeId, address indexed operator, address indexed by);

    /// @notice An operator's referrer was recorded, at its first registration.
    event OperatorReferrerRecorded(address indexed operator, address indexed referrer);

    /// @notice The caller doesn't hold OPERATOR_ROLE.
    error NotWhitelisted(address account);

    /// @notice The PeerID belongs to another operator.
    error PeerIdTaken(bytes32 nodeId, address operator);

    /// @notice The PeerID is empty or not in an accepted form.
    error InvalidPeerId();

    /// @notice No node has this id.
    error UnknownNode(bytes32 nodeId);

    /// @notice The node isn't in a status that allows this call.
    error InvalidStatus(bytes32 nodeId, NodeStatus status);

    /// @notice A validator tried to validate a node it operates.
    error SelfValidation(bytes32 nodeId);

    /// @notice The caller is neither the node's operator nor the admin Safe.
    error NotNodeOperator(bytes32 nodeId, address caller);

    /// @notice An operator named itself as referrer on its first registration.
    error SelfReferral();

    /// @notice Validates a Pending node, making it Validated.
    /// @dev Only VALIDATOR_ROLE, and not the node's operator. Reverts with {UnknownNode}, {InvalidStatus} or
    /// {SelfValidation}. Emits {NodeValidated}.
    /// @param nodeId keccak256 of the node's binary PeerID.
    function validateNode(bytes32 nodeId) external;

    /// @notice Deactivates a Pending or Validated node.
    /// @dev Only the node's operator, whether or not it is still whitelisted, or DEFAULT_ADMIN_ROLE. Reverts
    /// with {UnknownNode}, {InvalidStatus} or {NotNodeOperator}. Emits {NodeDeactivated}.
    /// @param nodeId keccak256 of the node's binary PeerID.
    function deactivateNode(bytes32 nodeId) external;

    /// @notice A node's record. All fields are zero for an unknown id.
    function nodeOf(bytes32 nodeId) external view returns (Node memory);

    /// @notice Whether a node counts for payouts now: Validated, and its operator holds OPERATOR_ROLE.
    function isOperational(bytes32 nodeId) external view returns (bool);

    /// @notice How many of the operator's nodes are Validated, whether or not it is still whitelisted.
    function validatedNodeCount(address operator) external view returns (uint256);

    /// @notice Whether the operator is active for Network Pool shares now: it holds OPERATOR_ROLE and has at
    /// least one Validated node.
    function isOperatorActive(address operator) external view returns (bool);

    /// @notice The referrer recorded for an operator; zero if none.
    function operatorReferrerOf(address operator) external view returns (address);

    /// @notice keccak256 of a binary PeerID: the node id this registry uses.
    function nodeIdOf(bytes calldata peerId) external pure returns (bytes32);
}
