// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0.0;

// The purpose of this contract is to offer ERC20 SkypierToken to our users

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract SkypierToken is Initializable, ERC20Upgradeable {
    function initialize() public initializer {
        __ERC20_init("SkypierToken", "SKP");
        _mint(msg.sender, 21 * 10**9 * 10**decimals());
    }
}