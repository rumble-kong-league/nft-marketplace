// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Marketplace.sol";

contract MarketplaceTest is Test {

    Marketplace marketplace;

    function setUp() public {
        marketplace = new Marketplace();
    }

    function testIncrementNonceForContract() public {
        address userAddress = vm.addr(1); // random address

        assertEq(marketplace.getCurrentNonceForAddress(userAddress),0);

        marketplace.incrementCurrentNonceForAddress(userAddress);

        assertEq(marketplace.getCurrentNonceForAddress(userAddress),1);
    }
}
