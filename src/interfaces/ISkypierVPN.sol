// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @dev The first 6 bytes of every PeerID the registry accepts: identity multihash (0x00), length 37 (0x25),
/// then the libp2p PublicKey protobuf header for a Secp256k1 key (Type = 2: 0x08 0x02; Data, 33 bytes:
/// 0x12 0x21). The 33-byte compressed public key follows.
bytes6 constant SECP256K1_PEER_ID_PREFIX = 0x002508021221;

/// @dev Length in bytes of an accepted PeerID: the 6-byte prefix plus a 33-byte compressed public key.
uint256 constant SECP256K1_PEER_ID_LENGTH = 39;

/// @dev EIP-712 type the node key signs to approve its registration by one operator.
bytes32 constant REGISTER_NODE_TYPEHASH = keccak256("RegisterNode(address operator,bytes peerId)");

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
/// - Only secp256k1 PeerIDs are accepted: exactly {SECP256K1_PEER_ID_LENGTH} bytes, starting with
///   {SECP256K1_PEER_ID_PREFIX}. Such a PeerID contains the node's public key, so each PeerID has one binary
///   form and one node id.
/// - Registration needs the node key's consent: an EIP-712 signature, by the key inside the PeerID, over
///   RegisterNode(operator, peerId). This stops an operator registering a PeerID it doesn't run. The node
///   key's Ethereum-style address (`nodeKey`) is stored and emitted.
/// - One operator per PeerID, for life: once registered, no other operator can take it.
/// - Lifecycle: None -> Pending (registered) -> Validated -> Deactivated. The same operator can register a
///   Deactivated PeerID again; it goes back to Pending and needs validating again.
/// - A validator can't validate a node it operates.
/// - A node is operational while it is Validated and its operator holds OPERATOR_ROLE. Revoking the role stops
///   all of that operator's nodes at once; granting it again revives its Validated nodes.
/// - An operator's referrer is recorded once, at its first registration, and can't be the operator.
///
///
/// Signing for a node (the Go node's "sign registration" step): take the node's secp256k1 private key, build
/// the EIP-712 digest with {registrationDigest} (or off-chain with the same domain: name "SkypierVPN",
/// version "1", the chain id and this contract's address), and sign it the Ethereum way (65 bytes r, s, v).
/// libp2p's own Sign (SHA-256 and DER) produces a different signature and is rejected.
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
    /// @param nodeKey The Ethereum-style address of the node's secp256k1 key; set at registration, never changes.
    struct Node {
        address operator;
        NodeStatus status;
        uint48 registeredAt;
        uint48 validatedAt;
        uint48 deactivatedAt;
        address validator;
        address nodeKey;
    }

    /// @notice A node was registered, or registered again after deactivation.
    /// @param nodeId keccak256 of `peerId`.
    /// @param operator The registering operator.
    /// @param peerId The PeerID in binary form.
    /// @param nodeKey The Ethereum-style address of the key inside the PeerID.
    event NodeRegistered(bytes32 indexed nodeId, address indexed operator, bytes peerId, address nodeKey);

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

    /// @notice The PeerID is not a {SECP256K1_PEER_ID_LENGTH}-byte secp256k1 PeerID.
    error InvalidPeerId();

    /// @notice `pubKeyY` doesn't complete the key in the PeerID: wrong parity, or not on the curve.
    error InvalidNodeKey();

    /// @notice The signature isn't the node key's signature over this operator and PeerID.
    error InvalidNodeSignature();

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

    /// @notice Registers a node for the caller, or registers again a node the caller deactivated.
    /// @dev Only OPERATOR_ROLE ({NotWhitelisted} otherwise). Checks, in order:
    /// - `peerId` is a secp256k1 PeerID ({InvalidPeerId});
    /// - `pubKeyY` is the y coordinate that matches the compressed key in `peerId`: same parity as its prefix
    ///   byte (0x02 even, 0x03 odd), below the field prime, and on the curve ({InvalidNodeKey});
    /// - `nodeSignature` recovers to the address keccak256(x, y) of that key, over {registrationDigest} for
    ///   the caller ({InvalidNodeSignature}; high-s signatures are rejected);
    /// - the PeerID is new, or Deactivated and the caller's ({PeerIdTaken} for another operator's,
    ///   {InvalidStatus} if it is Pending or Validated).
    /// The node becomes Pending. On the caller's first registration a non-zero `referrer` is recorded for
    /// good ({SelfReferral} if it is the caller); later referrers are ignored.
    /// Emits {NodeRegistered}, and {OperatorReferrerRecorded} on a first registration with a referrer.
    /// @param peerId The PeerID in binary form ({SECP256K1_PEER_ID_LENGTH} bytes).
    /// @param referrer Who referred the operator; zero for none. Only read on its first registration.
    /// @param pubKeyY The y coordinate of the node's public key; x is inside `peerId`.
    /// @param nodeSignature The node key's 65-byte signature over {registrationDigest}(caller, peerId).
    /// @return nodeId keccak256 of `peerId`.
    function registerNode(bytes calldata peerId, address referrer, bytes32 pubKeyY, bytes calldata nodeSignature)
        external
        returns (bytes32 nodeId);

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

    /// @notice The EIP-712 digest a node key signs to approve registration by `operator`.
    /// @param operator The operator that will call {registerNode}.
    /// @param peerId The node's PeerID in binary form.
    function registrationDigest(address operator, bytes calldata peerId) external view returns (bytes32);

    /// @notice keccak256 of a binary PeerID: the node id this registry uses.
    function nodeIdOf(bytes calldata peerId) external pure returns (bytes32);
}
