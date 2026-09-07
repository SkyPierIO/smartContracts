// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title ExpiryManagement
 * @dev Library for managing token expiry dates across contracts
 */
library ExpiryManagement {
    struct ExpiryInfo {
        uint64 expiryTime;
        bool isActive;
    }

    event ExpirySet(uint256 indexed tokenId, uint64 expiryTime);
    event ExpiryRevoked(uint256 indexed tokenId);

    /**
     * @dev Check if a token has expired
     */
    function isExpired(ExpiryInfo storage info) internal view returns (bool) {
        return info.isActive && block.timestamp >= info.expiryTime;
    }

    /**
     * @dev Check if a token is still valid (not expired and active)
     */
    function isValid(ExpiryInfo storage info) internal view returns (bool) {
        return info.isActive && block.timestamp < info.expiryTime;
    }

    /**
     * @dev Set expiry time for a token
     */
    function setExpiry(
        ExpiryInfo storage info,
        uint256 durationInSeconds
    ) internal {
        info.expiryTime = uint64(block.timestamp + durationInSeconds);
        info.isActive = true;
        emit ExpirySet(0, info.expiryTime);
    }

    /**
     * @dev Set expiry time using an absolute timestamp.
     */
    function setExpiryAbsolute(
        ExpiryInfo storage info,
        uint64 absoluteTimestamp
    ) internal {
        info.expiryTime = absoluteTimestamp;
        info.isActive = true;
        emit ExpirySet(0, info.expiryTime);
    }

    /**
     * @dev Extend expiry time
     */
    function extendExpiry(
        ExpiryInfo storage info,
        uint256 additionalDuration
    ) internal {
        require(info.isActive, "Token not active");
        info.expiryTime = uint64(info.expiryTime + additionalDuration);
    }

    /**
     * @dev Revoke expiry (make permanent)
     */
    function revokeExpiry(ExpiryInfo storage info) internal {
        info.isActive = false;
        emit ExpiryRevoked(0);
    }

    /**
     * @dev Get time remaining until expiry (returns 0 if expired)
     */
    function getTimeRemaining(ExpiryInfo storage info) internal view returns (uint256) {
        if (!info.isActive) return 0;
        if (block.timestamp >= info.expiryTime) return 0;
        return info.expiryTime - block.timestamp;
    }
}
