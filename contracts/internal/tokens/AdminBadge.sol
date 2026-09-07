// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {BaseAccessControlledUpgradeableToken} from "../../lib/BaseAccessControlledUpgradeableToken.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";


/**
 * @title AdminBadge
 * @dev Upgradeable ERC1155-based admin badge; minted only by builder token holders.
 */
contract AdminBadge is Initializable, BaseAccessControlledUpgradeableToken {
    uint256 private _nextTokenId;
    address public builderToken;
    uint256 public builderTokenId;

    event RoleGranted(address indexed account, bytes32 indexed role);
    event RoleRevoked(address indexed account, bytes32 indexed role);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        string memory uri,
        address _builderToken,
        uint256 _builderTokenId,
        address admin
    ) public initializer {
        __BaseAccessControlledUpgradeableToken_init(uri);
        builderToken = _builderToken;
        builderTokenId = _builderTokenId;
        if (admin != msg.sender) {
            _grantRole(DEFAULT_ADMIN_ROLE, admin);
        }
    }

    modifier onlyBuilderTokenHolder() {
        require(
            IERC1155(builderToken).balanceOf(msg.sender, builderTokenId) > 0,
            "Must hold Builder Token"
        );
        _;
    }

    function mintAdminBadge(address to)
        external
        onlyBuilderTokenHolder
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(to != address(0), "Cannot mint to zero address");
        uint256 tokenId = _nextTokenId++;
        _safeMintWithRole(to, tokenId, 1, "");
        grantRole(DEFAULT_ADMIN_ROLE, to);
        emit RoleGranted(to, DEFAULT_ADMIN_ROLE);
    }

    function burnAdminBadge(address from, uint256 tokenId) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _safeBurnWithRole(from, tokenId, 1);
        revokeRole(DEFAULT_ADMIN_ROLE, from);
        emit RoleRevoked(from, DEFAULT_ADMIN_ROLE);
    }

    function _beforeTokenTransfer(
        address /*operator*/,
        address from,
        address to,
        uint256[] memory /*ids*/,
        uint256[] memory /*amounts*/,
        bytes memory /*data*/
    ) internal {
        require(from == address(0) || to == address(0), "Admin badge is soulbound");
    }
}