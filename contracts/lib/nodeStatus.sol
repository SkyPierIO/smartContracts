// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract NodeStatusContract is Initializable, ERC721Upgradeable, UUPSUpgradeable, OwnableUpgradeable {
    struct Node {
        string peerId;
        string status; // Can be a string json
    }

    mapping(uint256 => Node) public nodes;

    uint256 private _tokenIdCounter;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(string memory name, string memory symbol, address owner) public initializer {
        __ERC721_init(name, symbol);
        __UUPSUpgradeable_init();
        __Ownable_init(owner);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function mint(string memory peerId, string memory status) external onlyOwner {
        uint256 tokenId = ++_tokenIdCounter;
        _safeMint(msg.sender, tokenId);
        nodes[tokenId] = Node(peerId, status);
    }

    function updateStatus(uint256 tokenId, string memory peerId, string memory newStatus) external {
        require(_isApprovedOrOwner(msg.sender, tokenId), "Caller is not approved or owner");
        require(keccak256(abi.encodePacked(nodes[tokenId].peerId)) == keccak256(abi.encodePacked(peerId)), "PeerID does not match");

        nodes[tokenId].status = newStatus;
        emit StatusUpdated(tokenId, newStatus);
    }

    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view returns (bool) {
        address ownerAddress = ownerOf(tokenId);
        return (spender == ownerAddress || getApproved(tokenId) == spender || isApprovedForAll(ownerAddress, spender));
    }

    event StatusUpdated(uint256 indexed tokenId, string newStatus);

    // No custom beforeTokenTransfer logic required here; rely on ERC721Upgradeable defaults

    function _authorizeUpgrade(address) internal override onlyOwner {}
}
