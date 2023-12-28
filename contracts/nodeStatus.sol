// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract NodeStatusContract is ERC721 {
    struct Node {
        string peerId;
        string status; // Can be a string json
    }

    mapping(uint256 => Node) public nodes;

    constructor(
        string memory name,
        string memory symbol
    ) ERC721(name, symbol) {}

    // Assumes that the sender is the owner of the token being minted
    function mint(string memory peerId, string memory status) external {
        uint256 tokenId = totalSupply() + 1;
        _safeMint(msg.sender, tokenId);
        nodes[tokenId] = Node(peerId, status);
    }

    function updateStatus(
        uint256 tokenId,
        string memory peerId,
        string memory newStatus
    ) external {
        // Checks whether the caller is the owner or approved to operate the token
        require(
            _isApprovedOrOwner(msg.sender, tokenId),
            "Caller is not approved or owner"
        );
        // Verifies that the peerId provided matches the PeerID associated with the token
        require(
            keccak256(abi.encodePacked(nodes[tokenId].peerId)) ==
                keccak256(abi.encodePacked(peerId)),
            "PeerID does not match"
        );

        nodes[tokenId].status = newStatus;
        emit StatusUpdated(tokenId, newStatus);
    }

    event StatusUpdated(uint256 indexed tokenId, string newStatus);
}
