// contracts/lib/TokenBoundAccount.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/ITokenBoundAccount.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TokenBoundAccount is ITokenBoundAccount, ERC165, Ownable {
    address public immutable tokenContract;
    uint256 public immutable tokenId;

    constructor(address _tokenContract, uint256 _tokenId) {
        tokenContract = _tokenContract;
        tokenId = _tokenId;
    }

    function token() external view override returns (address tokenContract, uint256 tokenId) {
        return (tokenContract, tokenId);
    }

    function isValidSigner(address signer, bytes calldata) external view override returns (bool) {
        // In a real implementation, you would verify if the signer is authorized
        // For this example, we'll just check if the signer is the owner
        return signer == owner();
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return
            interfaceId == type(ITokenBoundAccount).interfaceId ||
            interfaceId == type(ERC165).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    // Fallback function to make the contract compatible with any calls
    fallback() external payable {
        // Can be extended to handle specific function calls
    }

    receive() external payable {
        // Can receive ETH
    }
}