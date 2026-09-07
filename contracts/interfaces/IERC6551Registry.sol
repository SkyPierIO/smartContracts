// contracts/interfaces/IERC6551Registry.sol
// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface IERC6551Registry {
    /**
     * @dev Emitted when an ERC-6551 account is created.
     * @param creator The address that created the account.
     * @param account The deployed ERC-6551 account address.
     * @param chainId The chain ID where the account was created.
     */
    event ERC6551AccountCreated(
        address indexed creator,
        address indexed account,
        uint256 indexed chainId,
        address implementation,
        address tokenContract,
        uint256 tokenId,
        uint256 salt
    );

    /**
     * @dev Creates an ERC-6551 account for a given NFT.
     * @param implementation The implementation contract for the account.
     * @param chainId The chain ID where the NFT exists.
     * @param tokenContract The address of the NFT contract.
     * @param tokenId The ID of the NFT.
     * @param salt A salt value to ensure unique account addresses.
     * @return The deployed account address.
     */
    function createAccount(
        address implementation,
        uint256 chainId,
        address tokenContract,
        uint256 tokenId,
        uint256 salt
    ) external returns (address);

    function createAccountWithOwner(
        address implementation,
        uint256 chainId,
        address tokenContract,
        uint256 tokenId,
        uint256 salt,
        address owner
    ) external returns (address);

    /**
     * @dev Computes the deterministic address of an ERC-6551 account.
     * @param implementation The implementation contract for the account.
     * @param chainId The chain ID where the NFT exists.
     * @param tokenContract The address of the NFT contract.
     * @param tokenId The ID of the NFT.
     * @param salt A salt value to ensure unique account addresses.
     * @return The computed account address.
     */
    function account(
        address implementation,
        uint256 chainId,
        address tokenContract,
        uint256 tokenId,
        uint256 salt
    ) external view returns (address);
}