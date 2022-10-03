// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import "../src/Marketplace.sol";
import "../test/TestERC20.sol";
import "../test/TestERC721.sol";
import "../test/TestTokenMinter.sol";

contract MarketplaceTest is TestTokenMinter {
    using Orders for Orders.Order;

    Marketplace marketplace;

    function setUp() public override {
        super.setUp();
        marketplace = new Marketplace();
    }

    function testIncrementNonceForContract() public {
        assertEq(marketplace.getCurrentNonceForAddress(alice), 0);

        marketplace.incrementCurrentNonceForAddress(alice);

        assertEq(marketplace.getCurrentNonceForAddress(alice), 1);
    }

    function testFulfillAskOrder() public {
        // Set up
        // Assert starting state
        uint256 startingAmount = 100;
        uint256 tokenPrice = 20;
        uint256 tokenId = 0;

        // Bob mints an ERC721 token
        test721_1.mint(bob, tokenId);
        assertEq(test721_1.balanceOf(alice), 0);
        assertEq(test721_1.balanceOf(bob), 1);
        assertEq(token1.balanceOf(alice), startingAmount);
        assertEq(token1.balanceOf(bob), startingAmount);

        // Bob creates an order to sell his nft for 20 ERC20 tokens
        Orders.Order memory order = Orders.Order(
            true,
            bob,
            "",
            0,
            1664461158,
            1664561158,
            address(test721_1),
            0,
            1,
            tokenPrice,
            address(token1),
            ""
        );

        // Bob approves the marketplace to transfer token 0 for him
        vm.prank(bob);
        test721_1.approve(address(marketplace), tokenId);
        
        // Alice approves marketplace to send ERC20 tokens for her
        vm.startPrank(alice);
        token1.approve(address(marketplace), tokenPrice);
        
        // Alice fulfills bobs order
        marketplace.fulfillOrder(order);

        // Assert that alice got the ERC721 token and bob the ERC20 tokens
        assertEq(test721_1.balanceOf(alice), 1);
        assertEq(test721_1.balanceOf(bob), 0);
        assert(token1.balanceOf(alice) < startingAmount);
        assert(token1.balanceOf(bob) > startingAmount);
    }

}
