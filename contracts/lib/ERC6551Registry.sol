// contracts/lib/ERC6551Registry.sol
// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../interfaces/IERC6551Registry.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {TokenBoundAccount} from "./TokenBoundAccount.sol";

contract ERC6551Registry is IERC6551Registry {
    constructor() {}

    function createAccount(
        address implementation,
        uint256 chainId,
        address tokenContract,
        uint256 tokenId,
        uint256 salt
    ) external override returns (address) {
        return _createAccount(implementation, chainId, tokenContract, tokenId, salt, msg.sender);
    }

    function createAccountWithOwner(
        address implementation,
        uint256 chainId,
        address tokenContract,
        uint256 tokenId,
        uint256 salt,
        address owner
    ) external override returns (address) {
        require(owner != address(0), "Invalid owner");
        return _createAccount(implementation, chainId, tokenContract, tokenId, salt, owner);
    }

    function _createAccount(
        address implementation,
        uint256 chainId,
        address tokenContract,
        uint256 tokenId,
        uint256 salt,
        address owner
    ) internal returns (address) {
        bytes32 cloneSalt = _salt(chainId, tokenContract, tokenId, salt);
        address accountAddr = Clones.cloneDeterministic(implementation, cloneSalt);
        TokenBoundAccount(payable(accountAddr)).initialize(tokenContract, tokenId, owner);

        emit ERC6551AccountCreated(
            msg.sender,
            accountAddr,
            chainId,
            implementation,
            tokenContract,
            tokenId,
            salt
        );

        return accountAddr;
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
        return Clones.predictDeterministicAddress(
            implementation,
            _salt(chainId, tokenContract, tokenId, salt),
            address(this)
        );
    }

    function _salt(uint256 chainId, address tokenContract, uint256 tokenId, uint256 salt)
        private
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(chainId, tokenContract, tokenId, salt));
    }
}