// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Vm} from "forge-std/Vm.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

import {IPaymentPool} from "../src/interfaces/IPaymentPool.sol";
import {Roles} from "../src/lib/Roles.sol";
import {PaymentPoolTestBase} from "./utils/PaymentPoolTestBase.sol";
import {TestMerkle} from "./utils/TestMerkle.sol";

/// @notice setMerkleRoot.
contract PaymentPoolRootTest is PaymentPoolTestBase {
    bytes32 internal constant ROOT = keccak256("root");

    function setUp() public override {
        super.setUp();
        _fund(NETWORK, 1_000_000);
    }

    function test_SetRoot_StoresAndEmits() public {
        vm.expectEmit(address(pool));
        emit IPaymentPool.MerkleRootSet(NETWORK, ROOT, 600_000, uint48(T0));
        vm.prank(safe);
        pool.setMerkleRoot(NETWORK, ROOT, 600_000, uint48(T0));

        (bytes32 root, uint256 received, uint256 claimed, uint256 rootTotal, uint48 lastEnd) = pool.poolLedger(NETWORK);
        assertEq(root, ROOT);
        assertEq(received, 1_000_000);
        assertEq(claimed, 0);
        assertEq(rootTotal, 600_000);
        assertEq(lastEnd, uint48(T0));
        (root,,, rootTotal, lastEnd) = pool.poolLedger(BUILDER);
        assertEq(root, bytes32(0));
        assertEq(rootTotal + lastEnd, 0);
    }

    function test_SetRoot_TotalMayEqualReceived() public {
        vm.prank(safe);
        pool.setMerkleRoot(NETWORK, ROOT, 1_000_000, uint48(T0));
        (,,, uint256 rootTotal,) = pool.poolLedger(NETWORK);
        assertEq(rootTotal, 1_000_000);
    }

    function test_SetRoot_OnlyAdmin() public {
        vm.prank(stranger);
        vm.expectRevert(_unauthorized(stranger, Roles.DEFAULT_ADMIN_ROLE));
        pool.setMerkleRoot(NETWORK, ROOT, 1, uint48(T0));
    }

    function test_SetRoot_RevertsForZeroRoot() public {
        vm.prank(safe);
        vm.expectRevert(IPaymentPool.InvalidRoot.selector);
        pool.setMerkleRoot(NETWORK, bytes32(0), 1, uint48(T0));
    }

    function test_SetRoot_RevertsWhenTotalExceedsReceived() public {
        vm.prank(safe);
        vm.expectRevert(
            abi.encodeWithSelector(IPaymentPool.TotalExceedsReceived.selector, NETWORK, 1_000_001, 1_000_000)
        );
        pool.setMerkleRoot(NETWORK, ROOT, 1_000_001, uint48(T0));
    }

    /// @dev Each pool is checked against its own receipts: the Builder Pool has received nothing here.
    function test_SetRoot_ChecksTheRightPool() public {
        vm.prank(safe);
        vm.expectRevert(abi.encodeWithSelector(IPaymentPool.TotalExceedsReceived.selector, BUILDER, 1, 0));
        pool.setMerkleRoot(BUILDER, ROOT, 1, uint48(T0));
    }

    function test_SetRoot_RevertsWhenTotalBelowClaimed() public {
        bytes32[] memory leaves = _postTwo(NETWORK, 600_000, 400_000);
        vm.prank(alice);
        pool.claim(NETWORK, 600_000, TestMerkle.proof(leaves, 0));

        vm.prank(safe);
        vm.expectRevert(abi.encodeWithSelector(IPaymentPool.TotalBelowClaimed.selector, NETWORK, 599_999, 600_000));
        pool.setMerkleRoot(NETWORK, ROOT, 599_999, uint48(T0));

        vm.prank(safe);
        pool.setMerkleRoot(NETWORK, ROOT, 600_000, uint48(T0)); // equal is fine
    }

    function test_SetRoot_RevertsForPeriodEndBeforeLast() public {
        vm.prank(safe);
        pool.setMerkleRoot(NETWORK, ROOT, 1, uint48(T0));
        vm.warp(T0 + 14 days);
        vm.prank(safe);
        vm.expectRevert(abi.encodeWithSelector(IPaymentPool.PeriodEndBeforeLast.selector, uint48(T0 - 1), uint48(T0)));
        pool.setMerkleRoot(NETWORK, ROOT, 1, uint48(T0 - 1));
    }

    /// @dev Re-posting the same period end is how a correction is made.
    function test_SetRoot_SamePeriodEndAllowed() public {
        vm.startPrank(safe);
        pool.setMerkleRoot(NETWORK, ROOT, 1, uint48(T0));
        pool.setMerkleRoot(NETWORK, keccak256("corrected"), 2, uint48(T0));
        vm.stopPrank();
        (bytes32 root,,, uint256 rootTotal,) = pool.poolLedger(NETWORK);
        assertEq(root, keccak256("corrected"));
        assertEq(rootTotal, 2);
    }

    function test_SetRoot_RevertsForPeriodEndInFuture() public {
        vm.prank(safe);
        vm.expectRevert(abi.encodeWithSelector(IPaymentPool.PeriodEndInFuture.selector, uint48(T0 + 1)));
        pool.setMerkleRoot(NETWORK, ROOT, 1, uint48(T0 + 1));
    }

    function test_SetRoot_WorksWhilePaused() public {
        vm.startPrank(safe);
        pool.pause();
        pool.setMerkleRoot(NETWORK, ROOT, 1, uint48(T0));
        vm.stopPrank();
        (bytes32 root,,,,) = pool.poolLedger(NETWORK);
        assertEq(root, ROOT);
    }
}

/// @notice claim and claimMany.
contract PaymentPoolClaimTest is PaymentPoolTestBase {
    bytes32[] internal networkLeaves; // alice 600_000, bob 400_000
    bytes32[] internal builderLeaves; // alice 200_000, bob 300_000

    function setUp() public override {
        super.setUp();
        _fund(NETWORK, 1_000_000);
        _fund(BUILDER, 500_000);
        networkLeaves = _postTwo(NETWORK, 600_000, 400_000);
        builderLeaves = _postTwo(BUILDER, 200_000, 300_000);
    }

    // ------------------------------------------------------------------ claim

    function test_Claim_PaysCallerAndEmits() public {
        vm.expectEmit(address(pool));
        emit IPaymentPool.Claimed(NETWORK, alice, 600_000, 600_000);
        vm.prank(alice);
        uint256 paid = pool.claim(NETWORK, 600_000, TestMerkle.proof(networkLeaves, 0));

        assertEq(paid, 600_000);
        assertEq(usdc.balanceOf(alice), 600_000);
        assertEq(pool.claimedOf(NETWORK, alice), 600_000);
        assertEq(_claimed(NETWORK), 600_000);
        assertEq(_claimed(BUILDER), 0);
        assertEq(usdc.balanceOf(address(pool)), 900_000);
    }

    function test_Claim_SecondClaimOfSameLeafReverts() public {
        bytes32[] memory proof = TestMerkle.proof(networkLeaves, 0);
        vm.startPrank(alice);
        pool.claim(NETWORK, 600_000, proof);
        vm.expectRevert(IPaymentPool.NothingToClaim.selector);
        pool.claim(NETWORK, 600_000, proof);
        vm.stopPrank();
    }

    function test_Claim_PaysOnlyTheIncreaseInANewRoot() public {
        vm.prank(alice);
        pool.claim(NETWORK, 600_000, TestMerkle.proof(networkLeaves, 0));

        _fund(NETWORK, 500_000);
        vm.warp(T0 + 14 days);
        bytes32[] memory leaves = _postTwo(NETWORK, 900_000, 600_000);
        vm.expectEmit(address(pool));
        emit IPaymentPool.Claimed(NETWORK, alice, 300_000, 900_000);
        vm.prank(alice);
        assertEq(pool.claim(NETWORK, 900_000, TestMerkle.proof(leaves, 0)), 300_000);
        assertEq(usdc.balanceOf(alice), 900_000);
    }

    function test_Claim_RevertsForWrongAmount() public {
        bytes32[] memory proof = TestMerkle.proof(networkLeaves, 0);
        vm.prank(alice);
        vm.expectRevert(IPaymentPool.InvalidProof.selector);
        pool.claim(NETWORK, 600_001, proof);
    }

    /// @dev The leaf is built from msg.sender, so a copied proof pays nobody else.
    function test_Claim_RevertsForSomeoneElsesLeaf() public {
        bytes32[] memory proof = TestMerkle.proof(networkLeaves, 0);
        vm.prank(stranger);
        vm.expectRevert(IPaymentPool.InvalidProof.selector);
        pool.claim(NETWORK, 600_000, proof);
    }

    /// @dev The pool is inside the leaf: posting the Network tree as the Builder root releases nothing from the
    /// Builder Pool.
    function test_Claim_OnePoolsTreeCannotReleaseAnotherPoolsFunds() public {
        vm.prank(safe);
        pool.setMerkleRoot(BUILDER, TestMerkle.root(networkLeaves), 500_000, uint48(T0));
        bytes32[] memory proof = TestMerkle.proof(networkLeaves, 0);
        vm.prank(alice);
        vm.expectRevert(IPaymentPool.InvalidProof.selector);
        pool.claim(BUILDER, 600_000, proof);
    }

    function test_Claim_RevertsBeforeAnyRoot() public {
        PaymentPoolTestBase.setUp(); // fresh contracts, no roots
        bytes32[] memory proof = new bytes32[](0);
        vm.prank(alice);
        vm.expectRevert(IPaymentPool.InvalidProof.selector);
        pool.claim(NETWORK, 0, proof);
    }

    function test_Claim_OldProofFailsAfterNewRoot() public {
        bytes32[] memory oldProof = TestMerkle.proof(networkLeaves, 0);
        vm.warp(T0 + 14 days);
        _postTwo(NETWORK, 700_000, 300_000);
        vm.prank(alice);
        vm.expectRevert(IPaymentPool.InvalidProof.selector);
        pool.claim(NETWORK, 600_000, oldProof);
    }

    function test_Claim_RevertsWhilePaused() public {
        vm.prank(safe);
        pool.pause();
        bytes32[] memory proof = TestMerkle.proof(networkLeaves, 0);
        vm.prank(alice);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        pool.claim(NETWORK, 600_000, proof);
    }

    /// @dev The case the root checks can't catch: a correction that moves already-claimed money to someone else.
    /// The pool still never pays out more than it received.
    function test_Claim_InsufficientPoolBalanceAfterBadCorrection() public {
        vm.prank(alice);
        pool.claim(NETWORK, 600_000, TestMerkle.proof(networkLeaves, 0));

        // Breaks the payout-script rule: alice drops below what she claimed. Total 1_000_000 passes both checks.
        bytes32[] memory leaves = _postTwo(NETWORK, 100_000, 900_000);
        bytes32[] memory proof = TestMerkle.proof(leaves, 1);
        vm.prank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(IPaymentPool.InsufficientPoolBalance.selector, NETWORK, 900_000, 400_000)
        );
        pool.claim(NETWORK, 900_000, proof);
    }

    // ------------------------------------------------------------------ claimMany

    function test_ClaimMany_TwoPoolsOneTransfer() public {
        IPaymentPool.ClaimRequest[] memory requests = _aliceBoth();

        vm.recordLogs();
        vm.prank(alice);
        uint256 total = pool.claimMany(requests);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        assertEq(total, 800_000);
        assertEq(usdc.balanceOf(alice), 800_000);
        assertEq(pool.claimedOf(NETWORK, alice), 600_000);
        assertEq(pool.claimedOf(BUILDER, alice), 200_000);
        assertEq(_claimed(NETWORK), 600_000);
        assertEq(_claimed(BUILDER), 200_000);

        uint256 transfers;
        uint256 claims;
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter == address(usdc) && logs[i].topics[0] == IERC20.Transfer.selector) transfers++;
            if (logs[i].emitter == address(pool) && logs[i].topics[0] == IPaymentPool.Claimed.selector) {
                claims++;
                IPaymentPool.Pool p = IPaymentPool.Pool(uint8(uint256(logs[i].topics[1])));
                assertEq(address(uint160(uint256(logs[i].topics[2]))), alice);
                uint256 expected = p == NETWORK ? 600_000 : 200_000;
                assertEq(logs[i].data, abi.encode(expected, expected));
            }
        }
        assertEq(transfers, 1);
        assertEq(claims, 2);
    }

    function test_ClaimMany_SkipsPoolsWithNothingNew() public {
        vm.prank(alice);
        pool.claim(NETWORK, 600_000, TestMerkle.proof(networkLeaves, 0));

        vm.recordLogs();
        vm.prank(alice);
        assertEq(pool.claimMany(_aliceBoth()), 200_000);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        uint256 claims;
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter == address(pool) && logs[i].topics[0] == IPaymentPool.Claimed.selector) claims++;
        }
        assertEq(claims, 1);
        assertEq(usdc.balanceOf(alice), 800_000);
    }

    function test_ClaimMany_RevertsWhenNothingNew() public {
        IPaymentPool.ClaimRequest[] memory requests = _aliceBoth();
        vm.startPrank(alice);
        pool.claimMany(requests);
        vm.expectRevert(IPaymentPool.NothingToClaim.selector);
        pool.claimMany(requests);
        vm.stopPrank();
    }

    function test_ClaimMany_RevertsForEmptyList() public {
        IPaymentPool.ClaimRequest[] memory requests = new IPaymentPool.ClaimRequest[](0);
        vm.prank(alice);
        vm.expectRevert(IPaymentPool.NothingToClaim.selector);
        pool.claimMany(requests);
    }

    function test_ClaimMany_RepeatedPoolPaysOnce() public {
        IPaymentPool.ClaimRequest[] memory requests = new IPaymentPool.ClaimRequest[](3);
        bytes32[] memory proof = TestMerkle.proof(networkLeaves, 0);
        for (uint256 i; i < 3; ++i) {
            requests[i] = IPaymentPool.ClaimRequest(NETWORK, 600_000, proof);
        }
        vm.prank(alice);
        assertEq(pool.claimMany(requests), 600_000);
        assertEq(_claimed(NETWORK), 600_000);
    }

    function test_ClaimMany_OneInvalidProofRevertsAll() public {
        IPaymentPool.ClaimRequest[] memory requests = _aliceBoth();
        requests[1].cumulativeAmount = 200_001;
        vm.prank(alice);
        vm.expectRevert(IPaymentPool.InvalidProof.selector);
        pool.claimMany(requests);
        assertEq(pool.claimedOf(NETWORK, alice), 0);
        assertEq(usdc.balanceOf(alice), 0);
    }

    function test_ClaimMany_OneShortPoolRevertsAll() public {
        // Bob drains part of the Builder Pool, then a bad correction promises alice more than is left.
        vm.prank(bob);
        pool.claim(BUILDER, 300_000, TestMerkle.proof(builderLeaves, 1));
        bytes32[] memory leaves = _postTwo(BUILDER, 400_000, 100_000);

        IPaymentPool.ClaimRequest[] memory requests = new IPaymentPool.ClaimRequest[](2);
        requests[0] = IPaymentPool.ClaimRequest(NETWORK, 600_000, TestMerkle.proof(networkLeaves, 0));
        requests[1] = IPaymentPool.ClaimRequest(BUILDER, 400_000, TestMerkle.proof(leaves, 0));
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(IPaymentPool.InsufficientPoolBalance.selector, BUILDER, 400_000, 200_000)
        );
        pool.claimMany(requests);
        assertEq(pool.claimedOf(NETWORK, alice), 0);
    }

    function test_ClaimMany_RevertsWhilePaused() public {
        IPaymentPool.ClaimRequest[] memory requests = _aliceBoth();
        vm.prank(safe);
        pool.pause();
        vm.prank(alice);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        pool.claimMany(requests);
    }

    function test_ClaimMany_PaysOnlyTheCaller() public {
        IPaymentPool.ClaimRequest[] memory requests = _aliceBoth();
        vm.prank(stranger);
        vm.expectRevert(IPaymentPool.InvalidProof.selector);
        pool.claimMany(requests);
    }

    function _aliceBoth() private view returns (IPaymentPool.ClaimRequest[] memory requests) {
        requests = new IPaymentPool.ClaimRequest[](2);
        requests[0] = IPaymentPool.ClaimRequest(NETWORK, 600_000, TestMerkle.proof(networkLeaves, 0));
        requests[1] = IPaymentPool.ClaimRequest(BUILDER, 200_000, TestMerkle.proof(builderLeaves, 0));
    }
}
