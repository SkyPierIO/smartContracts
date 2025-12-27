// contracts/product/tokens/SkypierToken.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
// The purpose of this contract is to offer ERC20 SkypierToken to our users

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract SkypierToken is ERC20, AccessControl {
    bytes32 private constant CLIENT_ROLE = keccak256("CLIENT_ROLE");

    constructor() ERC20("Skypier Token", "SKY") {
        _mint(msg.sender, 1000000 * 10**decimals());
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    // function initialize() public initializer {
    //     __ERC20_init("SkypierToken", "SKP");
    //     _mint(msg.sender, 21 * 10**9 * 10**decimals());
    // }


    function mintClientToken(address to, uint256 amount) external {
        require(hasRole(CLIENT_ROLE, msg.sender), "Not authorized");
        _mint(to, amount);
    }
}