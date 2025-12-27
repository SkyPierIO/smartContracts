// contracts/interfaces/IERC6551Registry.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC6551Registry {
    event ERC6551AccountCreated(
        address indexed account,
        address indexed implementation,
        uint256 indexed chainId,
        address indexed tokenContract,
        uint256 indexed tokenId,
        uint256 salt
    );

    function createAccount(
        address implementation,
        uint256 chainId,
        address tokenContract,
        uint256 tokenId,
        uint256 salt
    ) external returns (address);

    function account(
        address implementation,
        uint256 chainId,
        address tokenContract,
        uint256 tokenId,
        uint256 salt
    ) external view returns (address);
}