// contracts/product/PaymentPoolHelper.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./PaymentPool.sol";

contract PaymentPoolHelper {
    PaymentPool public paymentPool;

    constructor(address _paymentPool) {
        paymentPool = PaymentPool(_paymentPool);
    }

    /**
     * @dev Gets all active operator addresses
     * @return address[] Array of active operator addresses
     */
    function getActiveOperators() external view returns (address[] memory) {
        // In a real implementation, you would need to track active operators
        // This is a simplified version that returns the keys set in PaymentPool
        return paymentPool.operatorsKeys();
    }

    /**
     * @dev Gets all active validator addresses
     * @return address[] Array of active validator addresses
     */
    function getActiveValidators() external view returns (address[] memory) {
        // In a real implementation, you would need to track active validators
        return paymentPool.validatorsKeys();
    }

    /**
     * @dev Gets all active builder addresses
     * @return address[] Array of active builder addresses
     */
    function getActiveBuilders() external view returns (address[] memory) {
        // In a real implementation, you would need to track active builders
        return paymentPool.buildersKeys();
    }

    /**
     * @dev Updates all mapping keys in one call
     */
    function updateAllKeys(
        address[] memory _operatorKeys,
        address[] memory _validatorKeys,
        address[] memory _builderKeys
    ) external {
        paymentPool.updateMappingKeys("operators", _operatorKeys);
        paymentPool.updateMappingKeys("validators", _validatorKeys);
        paymentPool.updateMappingKeys("builders", _builderKeys);
    }
}