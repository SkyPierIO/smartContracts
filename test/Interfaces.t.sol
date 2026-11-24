// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {BETA_TESTER_BADGE_ID, CLIENT_TOKEN_ID, IClientToken} from "../src/interfaces/IClientToken.sol";
import {IPaymentPool} from "../src/interfaces/IPaymentPool.sol";
import {ISkypierVPN} from "../src/interfaces/ISkypierVPN.sol";

/// @notice Pins the function selectors, event topics, enum values and Merkle leaf format that code outside
/// the contracts relies on: the payout script, the Go VPN node and the Safe's transactions. A failing test
/// here means an outside consumer must change too.
contract InterfacesTest is Test {
    // ---------------------------------------------------------------- ClientToken

    function test_ClientTokenIds() public pure {
        assertEq(CLIENT_TOKEN_ID, 1);
        assertEq(BETA_TESTER_BADGE_ID, 2);
    }

    function test_ClientTokenSelectors() public pure {
        assertEq(IClientToken.isValid.selector, bytes4(keccak256("isValid(address,uint256)")));
        assertEq(IClientToken.expiryOf.selector, bytes4(keccak256("expiryOf(address,uint256)")));
        assertEq(IClientToken.extendAccess.selector, bytes4(keccak256("extendAccess(address,uint256,uint48)")));
        assertEq(IClientToken.burnClientToken.selector, bytes4(keccak256("burnClientToken()")));
        assertEq(IClientToken.adminTransfer.selector, bytes4(keccak256("adminTransfer(address,address,uint256)")));
        assertEq(IClientToken.setURI.selector, bytes4(keccak256("setURI(string)")));
    }

    function test_ClientTokenEvents() public pure {
        assertEq(IClientToken.AccessExtended.selector, keccak256("AccessExtended(address,uint256,uint48)"));
        assertEq(
            IClientToken.AccessTransferred.selector, keccak256("AccessTransferred(address,address,uint256,uint48)")
        );
        assertEq(IClientToken.AccessBurned.selector, keccak256("AccessBurned(address,uint256)"));
    }

    // ---------------------------------------------------------------- PaymentPool

    function test_PoolEnumValues() public pure {
        assertEq(uint8(IPaymentPool.Pool.Network), 0);
        assertEq(uint8(IPaymentPool.Pool.Builder), 1);
    }

    function test_PaymentPoolSelectors() public pure {
        assertEq(IPaymentPool.payForAccess.selector, bytes4(keccak256("payForAccess(uint256,uint256,address)")));
        assertEq(IPaymentPool.fundPool.selector, bytes4(keccak256("fundPool(uint8,uint256)")));
        assertEq(IPaymentPool.setMerkleRoot.selector, bytes4(keccak256("setMerkleRoot(uint8,bytes32,uint256,uint48)")));
        assertEq(IPaymentPool.claim.selector, bytes4(keccak256("claim(uint8,uint256,bytes32[])")));
        assertEq(IPaymentPool.setPricing.selector, bytes4(keccak256("setPricing(uint256,uint48,uint16,uint48)")));
        assertEq(IPaymentPool.setNetworkSplitBps.selector, bytes4(keccak256("setNetworkSplitBps(uint16)")));
        assertEq(IPaymentPool.pause.selector, bytes4(keccak256("pause()")));
        assertEq(IPaymentPool.unpause.selector, bytes4(keccak256("unpause()")));
    }

    function test_PaymentPoolEvents() public pure {
        assertEq(
            IPaymentPool.AccessPurchased.selector,
            keccak256("AccessPurchased(address,uint256,uint256,uint256,uint256,uint48)")
        );
        assertEq(IPaymentPool.ReferrerRecorded.selector, keccak256("ReferrerRecorded(address,address)"));
        assertEq(IPaymentPool.PoolFunded.selector, keccak256("PoolFunded(uint8,address,uint256)"));
        assertEq(IPaymentPool.MerkleRootSet.selector, keccak256("MerkleRootSet(uint8,bytes32,uint256,uint48)"));
        assertEq(IPaymentPool.Claimed.selector, keccak256("Claimed(uint8,address,uint256,uint256)"));
        assertEq(IPaymentPool.PricingUpdated.selector, keccak256("PricingUpdated(uint256,uint48,uint16,uint48)"));
        assertEq(IPaymentPool.NetworkSplitUpdated.selector, keccak256("NetworkSplitUpdated(uint16,uint16)"));
    }

    /// @dev Known-answer vector for the leaf format in IPaymentPool. The payout script must produce the same
    /// leaves and root. Values were computed independently of Solidity.
    function test_MerkleLeafFormat() public pure {
        bytes32 a = _leaf(IPaymentPool.Pool.Network, address(0xA11CE), 1_000_000);
        bytes32 b = _leaf(IPaymentPool.Pool.Network, address(0xB0B), 2_500_000);
        assertEq(a, 0xcfa477783ebf125a9c2ccbd5e952400c1dd390d04e1e880c048785e900719c97);
        assertEq(b, 0x9fd7d2e80c058ed700bae96ad7aff8137afc7b7b2ad868771b1281e3355f0b65);

        bytes32 root = 0x35152e7fd0bc3b32cb610677d212333ef886da827e57a2f631413dae139a012c;
        bytes32[] memory proof = new bytes32[](1);
        proof[0] = b;
        assertTrue(MerkleProof.verify(proof, root, a));
        proof[0] = a;
        assertTrue(MerkleProof.verify(proof, root, b));
    }

    /// @dev The same account and amount in the other pool is a different leaf, so a root posted to both
    /// pools by mistake can't be claimed twice.
    function test_MerkleLeafBindsPool() public pure {
        bytes32 network = _leaf(IPaymentPool.Pool.Network, address(0xA11CE), 1_000_000);
        bytes32 builder = _leaf(IPaymentPool.Pool.Builder, address(0xA11CE), 1_000_000);
        assertEq(builder, 0xfbb621558980b7a649b6bcb7242de13e4f8375af55a5701ffe3ef9eb5a56c38d);
        assertTrue(network != builder);

        bytes32 root = 0x35152e7fd0bc3b32cb610677d212333ef886da827e57a2f631413dae139a012c;
        bytes32[] memory proof = new bytes32[](1);
        proof[0] = _leaf(IPaymentPool.Pool.Network, address(0xB0B), 2_500_000);
        assertFalse(MerkleProof.verify(proof, root, builder));
    }

    function _leaf(IPaymentPool.Pool pool, address account, uint256 cumulativeAmount) internal pure returns (bytes32) {
        return keccak256(bytes.concat(keccak256(abi.encode(uint8(pool), account, cumulativeAmount))));
    }

    // ---------------------------------------------------------------- SkypierVPN

    function test_NodeStatusValues() public pure {
        assertEq(uint8(ISkypierVPN.NodeStatus.None), 0);
        assertEq(uint8(ISkypierVPN.NodeStatus.Pending), 1);
        assertEq(uint8(ISkypierVPN.NodeStatus.Validated), 2);
        assertEq(uint8(ISkypierVPN.NodeStatus.Deactivated), 3);
    }

    function test_SkypierVPNSelectors() public pure {
        assertEq(ISkypierVPN.validateNode.selector, bytes4(keccak256("validateNode(bytes32)")));
        assertEq(ISkypierVPN.deactivateNode.selector, bytes4(keccak256("deactivateNode(bytes32)")));
        assertEq(ISkypierVPN.isOperational.selector, bytes4(keccak256("isOperational(bytes32)")));
        assertEq(ISkypierVPN.isOperatorActive.selector, bytes4(keccak256("isOperatorActive(address)")));
    }

    /// @dev NodeRegistered is not pinned yet: its fields depend on item 11.
    function test_SkypierVPNEvents() public pure {
        assertEq(ISkypierVPN.NodeValidated.selector, keccak256("NodeValidated(bytes32,address,address)"));
        assertEq(ISkypierVPN.NodeDeactivated.selector, keccak256("NodeDeactivated(bytes32,address,address)"));
        assertEq(ISkypierVPN.OperatorReferrerRecorded.selector, keccak256("OperatorReferrerRecorded(address,address)"));
    }
}
