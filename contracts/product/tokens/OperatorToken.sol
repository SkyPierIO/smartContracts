// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract HostContract is
    ERC721,
    ERC721Enumerable,
    ERC721URIStorage,
    ERC721Burnable,
    Ownable
{
    // Events to show a list of all the nodes
    event HostRegistered(uint256 tokenId, string nodeId);
    event HostUnregistered(uint256 tokenId);

    // Keeps track of the next token ID to be minted.
    uint256 private _nextTokenId;

    // Constructor takes an address and sets the contract owner using the Ownable contract
    constructor(
        address initialOwner
    ) ERC721("NODE", "NODE") Ownable(initialOwner) {}

    // Overrides the base URI function from
    function _baseURI() internal pure override returns (string memory) {
        return "https://ipfs.io/ipfs/";
    }

    // A public function to mint a new NFT (host) with a unique ID, sets its URI, and emits the HostRegistered event.
    // It takes to (recipient address), uri (URI for the token), and nodeId as arguments.
    function safeMint(
        address to,
        string memory uri,
        string memory nodeId
    ) public {
        uint256 tokenId = _nextTokenId++;
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
        emit HostRegistered(tokenId, nodeId);
    }

    // The following functions are internal overrides required by Solidity due to multiple inheritance from various ERC721-related contracts.
    function _update(
        address to,
        uint256 tokenId,
        address auth
    ) internal override(ERC721, ERC721Enumerable) returns (address) {
        return super._update(to, tokenId, auth);
    }

    function _increaseBalance(
        address account,
        uint128 value
    ) internal override(ERC721, ERC721Enumerable) {
        super._increaseBalance(account, value);
    }

    // Returns the base URI prefix for token URIs.
    function tokenURI(
        uint256 tokenId
    ) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        override(ERC721, ERC721Enumerable, ERC721URIStorage)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
