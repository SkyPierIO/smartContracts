// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

import {ClientToken} from "../../src/ClientToken.sol";
import {CLIENT_TOKEN_ID} from "../../src/interfaces/IClientToken.sol";
import {Roles} from "../../src/lib/Roles.sol";

/// @notice Deploys ClientToken behind an ERC-1967 proxy, with the Safe as admin and a stand-in PaymentPool as minter.
abstract contract ClientTokenTestBase is Test {
    string internal constant URI_0 = "test://client-token/{id}.json";
    uint256 internal constant T0 = 1_800_000_000;
    uint48 internal constant UNIT = 30 days;
    uint48 internal constant MAX = type(uint48).max;

    address internal safe = makeAddr("safe");
    address internal minter = makeAddr("paymentPool");
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal stranger = makeAddr("stranger");

    ClientToken internal token;

    function setUp() public virtual {
        vm.warp(T0);
        token = _deploy(safe, URI_0);
        vm.prank(safe);
        token.grantRole(Roles.MINTER_ROLE, minter);
    }

    function _deploy(address admin, string memory uri_) internal returns (ClientToken) {
        ClientToken impl = new ClientToken();
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), abi.encodeCall(ClientToken.initialize, (admin, uri_)));
        return ClientToken(address(proxy));
    }

    function _extend(address account, uint48 duration) internal returns (uint48) {
        vm.prank(minter);
        return token.extendAccess(account, CLIENT_TOKEN_ID, duration);
    }

    function _adminTransfer(address from, address to) internal returns (uint48) {
        vm.prank(safe);
        return token.adminTransfer(from, to, CLIENT_TOKEN_ID);
    }

    function _expiry(address account) internal view returns (uint48) {
        return token.expiryOf(account, CLIENT_TOKEN_ID);
    }

    function _balance(address account) internal view returns (uint256) {
        return token.balanceOf(account, CLIENT_TOKEN_ID);
    }

    function _unauthorized(address account, bytes32 role) internal pure returns (bytes memory) {
        return abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, account, role);
    }
}
