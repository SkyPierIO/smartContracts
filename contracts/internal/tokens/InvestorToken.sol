// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {BaseAccessControlledUpgradeableToken} from "../../lib/BaseAccessControlledUpgradeableToken.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/**
 * @title InvestorToken
 * @dev ERC1155 upgradeable investor badge using shared base for access control
 */
contract InvestorToken is Initializable, BaseAccessControlledUpgradeableToken {
    uint256 public constant INVESTOR_BADGE = 0;

    // simple registry for investor amounts
    mapping(address => uint256) public investorAmounts;

    event InvestorAdded(address indexed investor, uint256 amount);
    event InvestorRemoved(address indexed investor);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(string memory uri, address admin) public initializer {
        __BaseAccessControlledUpgradeableToken_init(uri);
        if (admin != msg.sender) {
            _grantRole(DEFAULT_ADMIN_ROLE, admin);
        }
    }

    function mintInvestorBadge(address to, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(to != address(0), "Invalid recipient");
        investorAmounts[to] = amount;
        _mint(to, INVESTOR_BADGE, 1, abi.encodePacked(amount));
        emit InvestorAdded(to, amount);
    }

    function revokeInvestorBadge(address from) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _burn(from, INVESTOR_BADGE, 1);
        investorAmounts[from] = 0;
        emit InvestorRemoved(from);
    }

    function getInvestorAmount(address investor) public view returns (uint256) {
        return investorAmounts[investor];
    }
}
