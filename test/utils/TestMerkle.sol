// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Hashes} from "@openzeppelin/contracts/utils/cryptography/Hashes.sol";

import {IPaymentPool} from "../../src/interfaces/IPaymentPool.sol";

/// @notice Builds small Merkle trees in tests, with the same leaf format and sorted-pair hashing that
/// OpenZeppelin's MerkleProof checks. Layers pair neighbours; an odd node at the end moves up unchanged.
library TestMerkle {
    /// @dev The leaf format in IPaymentPool: double keccak of abi.encode(uint8 pool, account, cumulative).
    function leaf(IPaymentPool.Pool pool, address account, uint256 cumulativeAmount) internal pure returns (bytes32) {
        return keccak256(bytes.concat(keccak256(abi.encode(uint8(pool), account, cumulativeAmount))));
    }

    function root(bytes32[] memory leaves) internal pure returns (bytes32) {
        require(leaves.length > 0, "TestMerkle: no leaves");
        bytes32[] memory layer = leaves;
        while (layer.length > 1) {
            layer = _next(layer);
        }
        return layer[0];
    }

    function proof(bytes32[] memory leaves, uint256 index) internal pure returns (bytes32[] memory) {
        require(index < leaves.length, "TestMerkle: index");
        bytes32[] memory buffer = new bytes32[](64);
        uint256 length;
        bytes32[] memory layer = leaves;
        while (layer.length > 1) {
            uint256 sibling = index ^ 1;
            if (sibling < layer.length) buffer[length++] = layer[sibling];
            layer = _next(layer);
            index /= 2;
        }
        bytes32[] memory p = new bytes32[](length);
        for (uint256 i; i < length; ++i) {
            p[i] = buffer[i];
        }
        return p;
    }

    function _next(bytes32[] memory layer) private pure returns (bytes32[] memory next) {
        uint256 n = (layer.length + 1) / 2;
        next = new bytes32[](n);
        for (uint256 i; i < n; ++i) {
            uint256 j = 2 * i;
            next[i] = j + 1 < layer.length ? Hashes.commutativeKeccak256(layer[j], layer[j + 1]) : layer[j];
        }
    }
}
