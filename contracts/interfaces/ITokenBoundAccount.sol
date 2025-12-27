// contracts/interfaces/ITokenBoundAccount.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ITokenBoundAccount {
    function token() external view returns (address tokenContract, uint256 tokenId);

    function isValidSigner(address signer, bytes calldata) external view returns (bool);
}