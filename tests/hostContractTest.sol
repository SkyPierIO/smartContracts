pragma solidity >0.8.10;

import "forge-std/Test.sol";

contract HostContractTest is Test {
    uint256 testNumber;

    function setUp() public {
        testNumber = 42;
        nodeId = 42;
        tokenId = 42;
    }

    function test_getHost(address host) public view returns (NodeInfo memory) {
        // assertEq(testNumber, 42);
        return hostsToInfo[host];
    }

    function testFail_getHost(
        address host
    ) public view returns (NodeInfo memory) {
        // assertEq(testNumber, 42);
        return hostsToInfo[host];
    }

    function test_registerAsHost(string memory nodeId) public {
        if (!hostsToInfo[msg.sender].active) {
            hostsToInfo[msg.sender] = NodeInfo(nodeId, 0, true, 0);
            emit HostRegistered(msg.sender, nodeId);
        }
    }

    function test_unregisterAsHost(string memory nodeId) public {
        if (hostsToInfo[msg.sender].active) {
            hostsToInfo[msg.sender].nodeId = "";
            hostsToInfo[msg.sender].active = false;
            emit HostUnregistered(msg.sender, nodeId);
        }
    }

    function test_useHost(address host) public {
        hostsToInfo[host].users++;
    }

    // NFT functions
    function test_mintNFT(address to) external {
        uint256 tokenId = nextTokenId++;
        _mint(to, tokenId);
        activeNFTs[tokenId] = true;
        emit NFTMinted(tokenId, to);
    }

    function test_burnNFT(uint256 tokenId) external {
        require(ownerOf(tokenId) == msg.sender, "Caller is not the owner");
        _burn(tokenId);
        activeNFTs[tokenId] = false;
        burnedNFTs[tokenId] = true;
        emit NFTBurned(tokenId, msg.sender);
    }

    function test_isBurned(uint256 tokenId) external view returns (bool) {
        return burnedNFTs[tokenId];
    }
}
