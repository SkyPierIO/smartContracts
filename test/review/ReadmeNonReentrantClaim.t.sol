// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";

import {ClientToken} from "../../src/ClientToken.sol";
import {CLIENT_TOKEN_ID} from "../../src/interfaces/IClientToken.sol";
import {Roles} from "../../src/lib/Roles.sol";
import {ClientTokenTestBase} from "../utils/ClientTokenTestBase.sol";

/// @notice Receiver wallet granted DEFAULT_ADMIN_ROLE (e.g. the admin Safe itself receiving a token)
/// that calls `setURI` inside `onERC1155Received` while `extendAccess`'s `nonReentrant` lock is held.
contract SetUriInHookReceiver is IERC1155Receiver {
    ClientToken public immutable TOKEN;

    constructor(ClientToken token_) {
        TOKEN = token_;
    }

    function onERC1155Received(address, address, uint256, uint256, bytes calldata) external returns (bytes4) {
        TOKEN.setURI("test://updated-inside-hook/{id}.json");
        return IERC1155Receiver.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(address, address, uint256[] calldata, uint256[] calldata, bytes calldata)
        external
        pure
        returns (bytes4)
    {
        return IERC1155Receiver.onERC1155BatchReceived.selector;
    }

    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == type(IERC1155Receiver).interfaceId || interfaceId == type(IERC165).interfaceId;
    }
}

/// @notice Proves Info Finding #1: README.md:268 states "every state-changing function is `nonReentrant`",
/// whereas `setURI` (in IClientToken's state-changing section) does not carry `nonReentrant` and succeeds
/// when re-entered from `onERC1155Received` during `extendAccess`.
contract ReadmeNonReentrantClaimTest is ClientTokenTestBase {
    function test_ReadmeClaim_SetUriRevertsOnReentry() public {
        SetUriInHookReceiver adminWallet = new SetUriInHookReceiver(token);
        vm.prank(safe);
        token.grantRole(Roles.DEFAULT_ADMIN_ROLE, address(adminWallet));

        vm.prank(minter);
        vm.expectRevert(ReentrancyGuardTransient.ReentrancyGuardReentrantCall.selector);
        token.extendAccess(address(adminWallet), CLIENT_TOKEN_ID, UNIT);
    }
}
