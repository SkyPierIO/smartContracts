// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

/**
 * @title HumanResources
 * @dev Manages builder pool operations, allocations, and payouts with reentrancy protection
 */
contract HumanResources is
    Initializable,
    AccessControlUpgradeable,
    UUPSUpgradeable,
    ReentrancyGuardUpgradeable
{
    bytes32 public constant HR_MANAGER_ROLE = keccak256("HR_MANAGER_ROLE");
    bytes32 public constant TREASURER_ROLE = keccak256("TREASURER_ROLE");

    struct Builder {
        address wallet;
        string role;
        uint256 monthlyAllocation;
        uint256 lastPaymentTime;
        bool isActive;
    }

    mapping(address => Builder) public builders;
    address[] public activeBuilders;

    uint256 public totalBuilderAllocations;
    address payable public builderPoolWallet;

    event BuilderRegistered(address indexed builder, string role, uint256 allocation);
    event BuilderDeregistered(address indexed builder);
    event PaymentProcessed(address indexed builder, uint256 amount);
    event AllocationUpdated(address indexed builder, uint256 newAllocation);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address payable _builderPoolWallet) public initializer {
        require(_builderPoolWallet != address(0), "Invalid wallet");

        __AccessControl_init();
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(HR_MANAGER_ROLE, msg.sender);
        _grantRole(TREASURER_ROLE, msg.sender);

        builderPoolWallet = _builderPoolWallet;
    }

    function registerBuilder(
        address builderAddress,
        string memory role,
        uint256 monthlyAllocation
    ) external onlyRole(HR_MANAGER_ROLE) {
        require(builderAddress != address(0), "Invalid address");
        require(monthlyAllocation > 0, "Allocation must be > 0");

        builders[builderAddress] = Builder({
            wallet: builderAddress,
            role: role,
            monthlyAllocation: monthlyAllocation,
            lastPaymentTime: block.timestamp,
            isActive: true
        });

        totalBuilderAllocations += monthlyAllocation;
        activeBuilders.push(builderAddress);

        emit BuilderRegistered(builderAddress, role, monthlyAllocation);
    }

    function deregisterBuilder(address builderAddress) external onlyRole(HR_MANAGER_ROLE) {
        require(builders[builderAddress].isActive, "Builder not active");

        totalBuilderAllocations -= builders[builderAddress].monthlyAllocation;
        builders[builderAddress].isActive = false;

        emit BuilderDeregistered(builderAddress);
    }

    function updateBuilderAllocation(address builderAddress, uint256 newAllocation)
        external
        onlyRole(HR_MANAGER_ROLE)
    {
        require(builders[builderAddress].isActive, "Builder not active");

        totalBuilderAllocations -= builders[builderAddress].monthlyAllocation;
        builders[builderAddress].monthlyAllocation = newAllocation;
        totalBuilderAllocations += newAllocation;

        emit AllocationUpdated(builderAddress, newAllocation);
    }

    function processPayment(address builderAddress) external onlyRole(TREASURER_ROLE) nonReentrant {
        require(builders[builderAddress].isActive, "Builder not active");

        uint256 amount = builders[builderAddress].monthlyAllocation;
        require(amount > 0, "No allocation");

        builders[builderAddress].lastPaymentTime = block.timestamp;

        (bool success,) = payable(builderAddress).call{value: amount}("");
        require(success, "Payment failed");

        emit PaymentProcessed(builderAddress, amount);
    }

    function getBuilder(address builderAddress) public view returns (Builder memory) {
        return builders[builderAddress];
    }

    function getActiveBuildersCount() public view returns (uint256) {
        return activeBuilders.length;
    }

    receive() external payable {}

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyRole(DEFAULT_ADMIN_ROLE)
    {}
}
