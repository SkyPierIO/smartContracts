// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IValidatorEscrow} from "../interfaces/IValidatorEscrow.sol";

/**
 * @title ValidatorEscrow
 * @dev Holds validator stake and limits release or slashing to protocol authorities.
 */
contract ValidatorEscrow is Initializable, AccessControlUpgradeable, UUPSUpgradeable, IValidatorEscrow {
    bytes32 public constant STAKE_MANAGER_ROLE = keccak256("STAKE_MANAGER_ROLE");
    bytes32 public constant SLASHER_ROLE = keccak256("SLASHER_ROLE");

    mapping(address => Stake) private _stakes;

    event StakeDeposited(address indexed beneficiary, uint256 amount);
    event StakeReleased(address indexed beneficiary, address indexed recipient, uint256 amount);
    event StakeSlashed(address indexed beneficiary, address indexed recipient, uint256 amount);

    constructor() {
        _disableInitializers();
    }

    function initialize(address manager, address admin) external initializer {
        require(manager != address(0), "Invalid manager");
        require(admin != address(0), "Invalid admin");

        __AccessControl_init();
        __UUPSUpgradeable_init();
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(STAKE_MANAGER_ROLE, manager);
        _grantRole(SLASHER_ROLE, admin);
        _grantRole(SLASHER_ROLE, manager);
    }

    function depositFor(address beneficiary) external payable override onlyRole(STAKE_MANAGER_ROLE) {
        require(beneficiary != address(0), "Invalid beneficiary");
        require(msg.value > 0, "Stake must be greater than zero");
        require(!_stakes[beneficiary].active, "Stake already active");

        _stakes[beneficiary] = Stake(msg.value, block.timestamp, true);
        emit StakeDeposited(beneficiary, msg.value);
    }

    function releaseStake(address beneficiary, address payable recipient)
        external
        override
        onlyRole(STAKE_MANAGER_ROLE)
    {
        Stake memory stake = _stakes[beneficiary];
        require(stake.active, "Stake not active");
        require(recipient != address(0), "Invalid recipient");

        delete _stakes[beneficiary];
        _send(recipient, stake.amount);
        emit StakeReleased(beneficiary, recipient, stake.amount);
    }

    function slashStake(address beneficiary, address payable recipient, uint256 amount)
        external
        override
        onlyRole(SLASHER_ROLE)
    {
        Stake storage stake = _stakes[beneficiary];
        require(stake.active, "Stake not active");
        require(recipient != address(0), "Invalid recipient");
        require(amount > 0 && amount <= stake.amount, "Invalid slash amount");

        stake.amount -= amount;
        if (stake.amount == 0) stake.active = false;
        _send(recipient, amount);
        emit StakeSlashed(beneficiary, recipient, amount);
    }

    function getStake(address beneficiary) external view override returns (Stake memory) {
        return _stakes[beneficiary];
    }

    function _send(address payable recipient, uint256 amount) private {
        (bool success,) = recipient.call{value: amount}("");
        require(success, "Stake transfer failed");
    }

    function _authorizeUpgrade(address) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}
}
