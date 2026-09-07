// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../interfaces/ITokenBoundAccount.sol";
import {ERC165Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165Upgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract TokenBoundAccount is Initializable, ITokenBoundAccount, ERC165Upgradeable, OwnableUpgradeable {
    address public tokenContract;
    uint256 public tokenId;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _tokenContract, uint256 _tokenId, address owner_) public initializer {
        __ERC165_init();
        tokenContract = _tokenContract;
        tokenId = _tokenId;
        __Ownable_init(owner_);
    }

    function token() external view override returns (address, uint256) {
        return (tokenContract, tokenId);
    }

    function isValidSigner(address signer, bytes calldata) external view override returns (bool) {
        return signer == owner();
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165Upgradeable) returns (bool) {
        return
            interfaceId == type(ITokenBoundAccount).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    fallback() external payable {}

    receive() external payable {}
}