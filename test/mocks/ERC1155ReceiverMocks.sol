// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import {CLIENT_TOKEN_ID, IClientToken} from "../../src/interfaces/IClientToken.sol";

/// @notice A contract wallet that accepts ERC-1155 tokens, like a smart account would.
contract AcceptingReceiver is IERC1155Receiver {
    function onERC1155Received(address, address, uint256, uint256, bytes calldata) external pure returns (bytes4) {
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

/// @notice A receiver that, inside `onERC1155Received`, records the expiry it sees and tries to burn its token.
/// @dev Shows that ClientToken writes the expiry before calling the receiver, and that the burn is refused.
contract ReentrantReceiver is IERC1155Receiver {
    IClientToken public immutable token;
    uint48 public expirySeenInHook;
    bool public burnSucceeded;
    bytes public burnRevertData;

    constructor(IClientToken token_) {
        token = token_;
    }

    function onERC1155Received(address, address, uint256, uint256, bytes calldata) external returns (bytes4) {
        expirySeenInHook = token.expiryOf(address(this), CLIENT_TOKEN_ID);
        try token.burnClientToken() {
            burnSucceeded = true;
        } catch (bytes memory reason) {
            burnRevertData = reason;
        }
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

/// @notice A contract that does not implement the ERC-1155 receiver hook.
contract NonReceiver {}
