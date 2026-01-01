// contracts/product/tokens/SkypierToken.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
// The purpose of this contract is to offer ERC20 SkypierToken to our users

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Upgradeable.sol";
import "@openzeppelin/contracts/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

contract SkypierToken is ERC20Upgradeable, AccessControlUpgradeable, UUPSUpgradeable {
    function initialize() public initializer {
        __ERC20_init("SkypierToken", "SKP");
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _mint(msg.sender, 21 * 10**9 * 10**decimals());
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender); // Critical for UUPS
    }

    function upgradeTo(address newImplementation) public virtual override onlyRole(DEFAULT_ADMIN_ROLE) {
        _upgradeTo(newImplementation);
    }

    function transfer(address recipient, uint256 amount) external returns (bool);
}