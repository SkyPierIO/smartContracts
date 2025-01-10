// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// The purpose of this contract is to onboard operator nodes to the Skypier Network

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

interface ISkypierToken {
    function transfer(
        address recipient,
        uint256 amount
    ) external returns (bool);
}

interface ISkypierBadge {
    function mint(
        address account,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) external;
}

contract SkypierVPN is
    Initializable,
    OwnableUpgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable
{
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant VALIDATOR_ROLE = keccak256("VALIDATOR_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    uint256 public stakeAmount;
    uint256 public validatorCount;
    uint256 public validatedOperatorsCount;
    uint256 public denyListCount;

    mapping(address => string) public operatorsWaitingList;
    mapping(address => string) public validatedOperators;
    mapping(address => string) public revokesOperators;

    ISkypierToken public skypierToken;
    ISkypierBadge public skypierBadge;

    event NewOperatorApplication(address indexed operator, string peerId);
    event NewOperatorValidated(
        address indexed operator,
        string peerId,
        address validator
    );
    event NewOperatorRevoked(address indexed operator, string peerId);

    // event NodeDenied(address indexed operator, string peerId);

    function initialize(
        uint256 _stakeAmount,
        uint256 _validatorCount,
        address _skypierTokenAddress,
        address _skypierBadgeAddress
    ) public initializer {
        __Ownable_init();
        __AccessControl_init();
        __UUPSUpgradeable_init();

        stakeAmount = _stakeAmount;
        validatorCount = _validatorCount;
        skypierToken = ISkypierToken(_skypierTokenAddress);
        skypierBadge = ISkypierBadge(_skypierBadgeAddress);

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(ADMIN_ROLE, msg.sender);
    }

    
    modifier onlyAdmin() {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not an admin");
        _;
    }

    modifier onlyValidator() {
        require(
            hasRole(VALIDATOR_ROLE, msg.sender),
            "Caller is not a validator"
        );
        _;
    }

    modifier onlyOperator() {
        require(
            hasRole(OPERATOR_ROLE, msg.sender),
            "Caller is not an operator"
        );
        _;
    }

    function applyAsOperator(string memory peerId) external payable {
        require(msg.value == stakeAmount, "Incorrect stake amount");
        require(
            bytes(revokesOperators[msg.sender]).length == 0,
            "Operator is denied"
        );

        operatorsWaitingList[msg.sender] = peerId;
        emit NewOperatorApplication(msg.sender, peerId);
    }

    function validateOperator(address operator) external onlyValidator {
        require(
            bytes(operatorsWaitingList[operator]).length != 0,
            "Operator is not in waiting list"
        );

        validatedOperators[operator] = operatorsWaitingList[operator];
        delete operatorsWaitingList[operator];
        validatedOperatorsCount++;

        emit NewOperatorValidated(
            operator,
            validatedOperators[operator],
            msg.sender
        );
    }

    function revokeOperator(address operator) external onlyAdmin {
        require(
            bytes(validatedOperators[operator]).length != 0,
            "Operator is not validated"
        );

        revokesOperators[operator] = validatedOperators[operator];
        delete validatedOperators[operator];
        validatedOperatorsCount--;
        denyListCount++;

        emit NewOperatorRevoked(operator, revokesOperators[operator]);
    }

    function updateStakeAmount(uint256 newStakeAmount) external onlyAdmin {
        stakeAmount = newStakeAmount;
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    // Public view functions
    function getValidatedOperatorCount() external view returns (uint256) {
        return validatedOperatorsCount;
    }

    function getValidatorCount() external view returns (uint256) {
        return validatorCount;
    }

    function getDenyListCount() external view returns (uint256) {
        return denyListCount;
    }
}
