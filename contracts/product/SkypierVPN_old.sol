// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

// The purpose of this contract is to onboard operator nodes to the Skypier Network

import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {ERC1155Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
// import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

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
    ERC1155Upgradeable,
    // OwnableUpgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable
{
    // Role Assignment
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

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        uint256 _stakeAmount,
        uint256 _validatorCount,
        address _skypierTokenAddress,
        address _skypierBadgeAddress
    ) public initializer {
        // __Ownable_init(msg.sender);
        __ERC1155_init("");
        __AccessControl_init();
        __UUPSUpgradeable_init();

        stakeAmount = _stakeAmount;
        validatorCount = _validatorCount;
        skypierToken = ISkypierToken(_skypierTokenAddress);
        skypierBadge = ISkypierBadge(_skypierBadgeAddress);

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
    }

    // Only ADMIN_ROLE gets to upgrade
    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyRole(ADMIN_ROLE)
    {}

    // The following functions are overrides required by Solidity.

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC1155Upgradeable, AccessControlUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
    
    // Logic Starts
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
