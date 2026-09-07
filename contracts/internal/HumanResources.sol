// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {IPaymentPool} from "../interfaces/IPaymentPool.sol";
import {IInternalRoleTokens} from "../interfaces/IInternalRoleTokens.sol";

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
    uint256 public activeBuilderCount;
    address payable public builderPoolWallet;
    address public paymentPool;
    IInternalRoleTokens public builderToken;
    IInternalRoleTokens public employeeBadge;
    IInternalRoleTokens public adminBadge;

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
        require(!builders[builderAddress].isActive, "Builder already active");

        builders[builderAddress] = Builder({
            wallet: builderAddress,
            role: role,
            monthlyAllocation: monthlyAllocation,
            lastPaymentTime: block.timestamp,
            isActive: true
        });

        totalBuilderAllocations += monthlyAllocation;
        activeBuilders.push(builderAddress);
        activeBuilderCount++;
        if (paymentPool != address(0)) IPaymentPool(paymentPool).registerBuilder(payable(builderAddress));

        emit BuilderRegistered(builderAddress, role, monthlyAllocation);
    }

    function deregisterBuilder(address builderAddress) external onlyRole(HR_MANAGER_ROLE) {
        require(builders[builderAddress].isActive, "Builder not active");

        totalBuilderAllocations -= builders[builderAddress].monthlyAllocation;
        builders[builderAddress].isActive = false;
        activeBuilderCount--;

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

        if (paymentPool != address(0)) {
            IPaymentPool(paymentPool).payBuilderPayment(payable(builderAddress), amount);
        } else {
            (bool success,) = payable(builderAddress).call{value: amount}("");
            require(success, "Payment failed");
        }

        emit PaymentProcessed(builderAddress, amount);
    }

    function getBuilder(address builderAddress) public view returns (Builder memory) {
        return builders[builderAddress];
    }

    function setPaymentPool(address newPaymentPool) external onlyRole(DEFAULT_ADMIN_ROLE) {
        paymentPool = newPaymentPool;
    }

    function setRoleDependencies(address newBuilderToken, address newEmployeeBadge, address newAdminBadge)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        builderToken = IInternalRoleTokens(newBuilderToken);
        employeeBadge = IInternalRoleTokens(newEmployeeBadge);
        adminBadge = IInternalRoleTokens(newAdminBadge);
    }

    function issueBuilderRole(address recipient) external onlyRole(HR_MANAGER_ROLE) {
        require(address(builderToken) != address(0), "Builder token not configured");
        builderToken.mintBuilderToken(recipient);
    }

    function issueEmployeeRole(address recipient, uint256 amount, uint256 customExpiryDuration)
        external
        onlyRole(HR_MANAGER_ROLE)
    {
        require(address(employeeBadge) != address(0), "Employee badge not configured");
        employeeBadge.mintEmployeeLevelBadge(recipient, amount, customExpiryDuration);
    }

    function issueAdminRole(address recipient) external onlyRole(HR_MANAGER_ROLE) {
        require(address(adminBadge) != address(0), "Admin badge not configured");
        adminBadge.mintAdminBadge(recipient);
    }

    function getActiveBuildersCount() public view returns (uint256) {
        return activeBuilderCount;
    }

    receive() external payable {}

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyRole(DEFAULT_ADMIN_ROLE)
    {}
}
