// contracts/lib/ERC6551Registry.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IERC6551Registry.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract ERC6551Registry is IERC6551Registry {
    using Counters for Counters.Counter;
    using ECDSA for bytes32;

    Counters.Counter private _accountNonce;

    bytes32 private constant ACCOUNT_CREATION_CODE_HASH =
        bytes32(0x6352211e274072c715c503f48d805c548b9817d71d6ab2a3ebc593d4628e7ee9);

    constructor() {
        _accountNonce.increment();
    }

    function createAccount(
        address implementation,
        uint256 chainId,
        address tokenContract,
        uint256 tokenId,
        uint256 salt
    ) external override returns (address) {
        address account = computeAccount(
            implementation,
            chainId,
            tokenContract,
            tokenId,
            salt
        );

        require(account.code.length == 0, "Account already deployed");

        emit ERC6551AccountCreated(
            account,
            implementation,
            chainId,
            tokenContract,
            tokenId,
            salt
        );

        return account;
    }

    function account(
        address implementation,
        uint256 chainId,
        address tokenContract,
        uint256 tokenId,
        uint256 salt
    ) external view override returns (address) {
        return computeAccount(
            implementation,
            chainId,
            tokenContract,
            tokenId,
            salt
        );
    }

    function computeAccount(
        address implementation,
        uint256 chainId,
        address tokenContract,
        uint256 tokenId,
        uint256 salt
    ) public view returns (address) {
        bytes32 hash = keccak256(
            abi.encodePacked(
                bytes1(0xff),
                address(this),
                salt,
                ACCOUNT_CREATION_CODE_HASH,
                implementation,
                chainId,
                tokenContract,
                tokenId,
                _accountNonce.current()
            )
        );

        return address(uint160(uint256(hash)));
    }
}