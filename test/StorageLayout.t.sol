// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {ClientTokenStorage} from "../src/lib/storage/ClientTokenStorage.sol";
import {PaymentPoolStorage} from "../src/lib/storage/PaymentPoolStorage.sol";
import {SkypierVPNStorage} from "../src/lib/storage/SkypierVPNStorage.sol";

/// @notice Checks each ERC-7201 slot constant against its namespace, so a typo can't move a contract's storage.
contract StorageLayoutTest is Test {
    function _erc7201(string memory namespace) internal pure returns (bytes32) {
        return keccak256(abi.encode(uint256(keccak256(bytes(namespace))) - 1)) & ~bytes32(uint256(0xff));
    }

    function test_ClientTokenSlot() public pure {
        assertEq(ClientTokenStorage.SLOT, _erc7201("skypier.storage.ClientToken"));
        ClientTokenStorage.Layout storage l = ClientTokenStorage.layout();
        bytes32 slot;
        assembly {
            slot := l.slot
        }
        assertEq(slot, ClientTokenStorage.SLOT);
    }

    function test_PaymentPoolSlot() public pure {
        assertEq(PaymentPoolStorage.SLOT, _erc7201("skypier.storage.PaymentPool"));
        PaymentPoolStorage.Layout storage l = PaymentPoolStorage.layout();
        bytes32 slot;
        assembly {
            slot := l.slot
        }
        assertEq(slot, PaymentPoolStorage.SLOT);
    }

    function test_SkypierVPNSlot() public pure {
        assertEq(SkypierVPNStorage.SLOT, _erc7201("skypier.storage.SkypierVPN"));
        SkypierVPNStorage.Layout storage l = SkypierVPNStorage.layout();
        bytes32 slot;
        assembly {
            slot := l.slot
        }
        assertEq(slot, SkypierVPNStorage.SLOT);
    }

    /// @dev The ERC-7201 formula itself, checked against OpenZeppelin's published AccessControl slot.
    function test_FormulaMatchesOpenZeppelin() public pure {
        assertEq(
            _erc7201("openzeppelin.storage.AccessControl"),
            0x02dd7bc7dec4dceedda775e58dd541e08a116c6c53815c0bd028192f7b626800
        );
    }

    /// @dev The low byte is cleared, as ERC-7201 requires, and the three namespaces never collide.
    function test_SlotsAreAlignedAndDistinct() public pure {
        assertEq(uint256(ClientTokenStorage.SLOT) & 0xff, 0);
        assertEq(uint256(PaymentPoolStorage.SLOT) & 0xff, 0);
        assertEq(uint256(SkypierVPNStorage.SLOT) & 0xff, 0);
        assertTrue(ClientTokenStorage.SLOT != PaymentPoolStorage.SLOT);
        assertTrue(ClientTokenStorage.SLOT != SkypierVPNStorage.SLOT);
        assertTrue(PaymentPoolStorage.SLOT != SkypierVPNStorage.SLOT);
    }
}
