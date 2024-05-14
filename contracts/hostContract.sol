// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract HostContract is ERC721 {
    // Events
    event HostRegistered(address indexed host, string nodeId);
    event HostUnregistered(address indexed host, string nodeId);
    event NFTMinted(uint256 indexed tokenId, address indexed owner);
    event NFTBurned(uint256 indexed tokenId, address indexed owner);

    /**
     * A smart contract that stores the hosts registered on the network
     * @author Ting & Miguel
     */
    struct NodeInfo {
        string nodeId;
        uint256 balance;
        bool active;
        uint users;
    }

    // State Variables
    address public immutable owner;
    mapping(address => NodeInfo) hostsToInfo;

    // NFTs
    mapping(uint256 => bool) public activeNFTs;
    mapping(uint256 => bool) public burnedNFTs;
    uint256 public nextTokenId;

    // Constructor: Called once on contract deployment
    constructor(address _owner) ERC721("NFT", "NFT") {
        owner = _owner;
    }

    function getHost(address host) public view returns (NodeInfo memory) {
        return hostsToInfo[host];
    }

    function registerAsHost(string memory nodeId) public {
        if (!hostsToInfo[msg.sender].active) {
            hostsToInfo[msg.sender] = NodeInfo(nodeId, 0, true, 0);
            emit HostRegistered(msg.sender, nodeId);
        }
    }

    function unregisterAsHost(string memory nodeId) public {
        if (hostsToInfo[msg.sender].active) {
            hostsToInfo[msg.sender].nodeId = "";
            hostsToInfo[msg.sender].active = false;
            emit HostUnregistered(msg.sender, nodeId);
        }
    }

    function useHost(address host) public {
        hostsToInfo[host].users++;
    }

    // NFT functions
    function mintNFT(address to) external {
        uint256 tokenId = nextTokenId++;
        _mint(to, tokenId);
        activeNFTs[tokenId] = true;
        emit NFTMinted(tokenId, to);
    }

    function burnNFT(uint256 tokenId) external {
        require(ownerOf(tokenId) == msg.sender, "Caller is not the owner");
        _burn(tokenId);
        activeNFTs[tokenId] = false;
        burnedNFTs[tokenId] = true;
        emit NFTBurned(tokenId, msg.sender);
    }

    function isBurned(uint256 tokenId) external view returns (bool) {
        return burnedNFTs[tokenId];
    }
}