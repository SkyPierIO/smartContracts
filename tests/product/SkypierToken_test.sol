// tests/product/SkypierToken_test.sol
// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.22 <0.9.0;

import "remix_tests.sol";
import "remix_accounts.sol";
import "../../contracts/product/tokens/SkypierToken.sol";

contract SkypierTokenTest {
    SkypierToken token;

    function beforeAll() public {
        token = new SkypierToken();
    }

    function testInitialSupply() public {
        Assert.equal(token.totalSupply(), 1000000 * 10**token.decimals(), "Initial supply incorrect");
    }
}