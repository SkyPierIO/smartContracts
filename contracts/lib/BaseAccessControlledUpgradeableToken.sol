// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ERC1155Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title BaseAccessControlledUpgradeableToken
 * @dev Abstract base contract for ERC1155 tokens with UUPS upgrade capability
 * and role-based access control. Reduces code duplication across token contracts.
 */
abstract contract BaseAccessControlledUpgradeableToken is
    Initializable,
    ERC1155Upgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable
{
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    bool public paused;

    event Paused(address indexed account);
    event Unpaused(address indexed account);

    modifier whenNotPaused() {
        require(!paused, "Token: paused");
        _;
    }

    modifier onlyMinter() {
        require(hasRole(MINTER_ROLE, msg.sender), "Must have minter role");
        _;
    }

    modifier onlyBurner() {
        require(hasRole(BURNER_ROLE, msg.sender), "Must have burner role");
        _;
    }

    modifier onlyPauser() {
        require(hasRole(PAUSER_ROLE, msg.sender), "Must have pauser role");
        _;
    }

    function __BaseAccessControlledUpgradeableToken_init(string memory uri) internal onlyInitializing {
        __ERC1155_init(uri);
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(BURNER_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
    }

    function pause() public onlyPauser {
        paused = true;
        emit Paused(msg.sender);
    }

    function unpause() public onlyPauser {
        paused = false;
        emit Unpaused(msg.sender);
    }

    function _safeMintWithRole(
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) internal onlyMinter whenNotPaused {
        _mint(to, id, amount, data);
    }

    function _safeBurnWithRole(
        address from,
        uint256 id,
        uint256 amount
    ) internal onlyBurner {
        _burn(from, id, amount);
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyRole(DEFAULT_ADMIN_ROLE)
    {}

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC1155Upgradeable, AccessControlUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
