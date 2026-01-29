// contracts/product/PaymentPoolHelper.sol
// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./PaymentPool.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract PaymentPoolHelper is Initializable, UUPSUpgradeable, OwnableUpgradeable {
    address payable public paymentPool;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address payable _paymentPool) public initializer {
        __UUPSUpgradeable_init();
        __Ownable_init(msg.sender);
        paymentPool = _paymentPool;
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}

    /**
     * @dev Gets all active operator addresses
     * @return address[] Array of active operator addresses
     */
    function getActiveOperators() external view returns (address[] memory) {
        // In a real implementation, you would need to track active operators
        // This is a simplified version that returns the keys set in PaymentPool
        return PaymentPool(paymentPool).getOperatorsKeys();
    }

    /**
     * @dev Gets all active validator addresses
     * @return address[] Array of active validator addresses
     */
    function getActiveValidators() external view returns (address[] memory) {
        // In a real implementation, you would need to track active validators
        return PaymentPool(paymentPool).getValidatorsKeys();
    }

    /**
     * @dev Gets all active builder addresses
     * @return address[] Array of active builder addresses
     */
    function getActiveBuilders() external view returns (address[] memory) {
        // In a real implementation, you would need to track active builders
        return PaymentPool(paymentPool).getBuildersKeys();
    }

    /**
     * @dev Updates all mapping keys in one call
     */
    function updateAllKeys(
        address[] memory _operatorKeys,
        address[] memory _validatorKeys,
        address[] memory _builderKeys
    ) external {
        PaymentPool(paymentPool).updateMappingKeys("operators", _operatorKeys);
        PaymentPool(paymentPool).updateMappingKeys("validators", _validatorKeys);
        PaymentPool(paymentPool).updateMappingKeys("builders", _builderKeys);
    }
}