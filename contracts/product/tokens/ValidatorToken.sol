// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ERC1155Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title ValidatorToken
 * @dev ERC-1155 non-transferable token for node validators
 * Represents validator status in the Skypier network
 */
contract ValidatorToken is
    Initializable,
    ERC1155Upgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable
{
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    uint256 public constant VALIDATOR_BADGE = 0;

    struct ValidatorInfo {
        address validatorAddress;
        uint256 stakingAmount;
        uint256 registeredAt;
        bool isActive;
    }

    mapping(address => ValidatorInfo) public validators;

    event ValidatorRegistered(address indexed validator, uint256 stakingAmount);
    event ValidatorDeregistered(address indexed validator);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() public initializer {
        __ERC1155_init("https://skypier.io/validator/{id}.json");
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(BURNER_ROLE, msg.sender);
    }

    function mintValidatorBadge(address to, uint256 stakingAmount)
        external
        onlyRole(MINTER_ROLE)
    {
        require(to != address(0), "Invalid recipient");
        require(stakingAmount > 0, "Staking amount must be > 0");

        _mint(to, VALIDATOR_BADGE, 1, "");

        validators[to] = ValidatorInfo({
            validatorAddress: to,
            stakingAmount: stakingAmount,
            registeredAt: block.timestamp,
            isActive: true
        });

        emit ValidatorRegistered(to, stakingAmount);
    }

    function revokeValidatorBadge(address from) external onlyRole(BURNER_ROLE) {
        require(balanceOf(from, VALIDATOR_BADGE) > 0, "Not a validator");

        _burn(from, VALIDATOR_BADGE, 1);
        validators[from].isActive = false;

        emit ValidatorDeregistered(from);
    }

    function getValidatorInfo(address validator) public view returns (ValidatorInfo memory) {
        return validators[validator];
    }

    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal {
        require(from == address(0) || to == address(0), "Validator token is soulbound");
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
