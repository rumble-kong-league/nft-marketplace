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

    uint256 constant FAR_PAST_TIMESTAMP = 0;
    uint256 constant FAR_FUTURE_TIMESTAMP = 3664561158;
    bytes constant EMPTY_STRING = "";

    event OrderFulfilled(
        address from,
        address to,
        address collection,
        uint256 tokenId,
        uint256 amount,
        address currency,
        uint256 price
    );

    function setUp() public override {
        super.setUp();
        marketplace = new Marketplace();
    }

    function setUpBobAskERC721Order() internal returns (Orders.Order memory) {
        // Set up
        // Assert starting state
        uint256 startingAmount = 100;
        uint256 tokenPrice = 20;

        // Bob mints an ERC721 token
        test721_1.mint(bob, 0);
        assertEq(test721_1.balanceOf(alice), 0);
        assertEq(test721_1.balanceOf(bob), 1);
        assertEq(token1.balanceOf(alice), startingAmount);
        assertEq(token1.balanceOf(bob), startingAmount);

        // Bob creates an order to sell his nft for 20 ERC20 tokens
        Orders.Order memory order = Orders.Order({
            isAsk: true,
            signer: bob,
            signature: EMPTY_STRING,
            nonce: 0,
            startTime: FAR_PAST_TIMESTAMP,
            endTime: FAR_FUTURE_TIMESTAMP,
            collection: address(test721_1),
            tokenId: 0,
            amount: 1,
            price: 20,
            currency: address(token1),
            params: EMPTY_STRING 
        });

        return order;
    }

    function setUpBobBidERC721Order() internal returns (Orders.Order memory) {
        // Set up
        // Assert starting state
        uint256 startingAmount = 100;
        uint256 tokenPrice = 20;

        // Alice mints an ERC721 token
        test721_1.mint(alice, 0);
        assertEq(test721_1.balanceOf(alice), 1);
        assertEq(test721_1.balanceOf(bob), 0);
        assertEq(token1.balanceOf(alice), startingAmount);
        assertEq(token1.balanceOf(bob), startingAmount);

        // Bob creates a bid order to buy alices NFT for 20 ERC20 tokens
        Orders.Order memory order = Orders.Order({
            isAsk: false,
            signer: bob,
            signature: EMPTY_STRING,
            nonce: 0,
            startTime: FAR_PAST_TIMESTAMP,
            endTime: FAR_FUTURE_TIMESTAMP,
            collection: address(test721_1),
            tokenId: 0,
            amount: 1,
            price: 20,
            currency: address(token1),
            params: EMPTY_STRING 
        });

        return order;
    }

    function setUpBobBidERC1155Order() internal returns (Orders.Order memory) {
        // Set up
        // Assert starting state
        uint256 startingAmount = 100;
        uint256 tokenPrice = 20;

        // Bob mints an ERC721 token
        test1155_1.mint(bob, 0, 10);
        assertEq(test1155_1.balanceOf(alice, 0), 0);
        assertEq(test1155_1.balanceOf(bob, 0), 10);
        assertEq(token1.balanceOf(alice), startingAmount);
        assertEq(token1.balanceOf(bob), startingAmount);

        // Bob creates an order to sell his nft for 20 ERC20 tokens
        Orders.Order memory order = Orders.Order({
            isAsk: true,
            signer: bob,
            signature: EMPTY_STRING,
            nonce: 0,
            startTime: FAR_PAST_TIMESTAMP,
            endTime: FAR_FUTURE_TIMESTAMP,
            collection: address(test1155_1),
            tokenId: 0,
            amount: 10,
            price: 20,
            currency: address(token1),
            params: EMPTY_STRING 
        });

        return order;
    }

    function assertBobAskERC721OrderFulfilled(uint256 startingAmount, uint256 tokenPrice) internal {
        assertEq(test721_1.balanceOf(alice), 1);
        assertEq(test721_1.balanceOf(bob), 0);
        assert(token1.balanceOf(alice) == startingAmount - tokenPrice);
        assert(token1.balanceOf(bob) == startingAmount + tokenPrice);
    }

    function assertBobBidERC721OrderFulfilled(uint256 startingAmount, uint256 tokenPrice) internal {
        assertEq(test721_1.balanceOf(bob), 1);
        assertEq(test721_1.balanceOf(alice), 0);
        assertEq(token1.balanceOf(bob), startingAmount - tokenPrice);
        assertEq(token1.balanceOf(alice), startingAmount + tokenPrice);
        assertEq(marketplace.getIsUserOrderNonceExecutedOrCanceled(bob, 0), true);
    }

    function assertBobBidERC1155OrderFulfilled(uint256 startingAmount, uint256 tokenPrice) internal {
        assertEq(test1155_1.balanceOf(bob, 0), 0);
        assertEq(test1155_1.balanceOf(alice, 0), 10);
        assertEq(token1.balanceOf(alice), startingAmount - tokenPrice);
        assertEq(token1.balanceOf(bob), startingAmount + tokenPrice);
        assertEq(marketplace.getIsUserOrderNonceExecutedOrCanceled(bob, 0), true);
    }

    function testIncrementNonceForContract() public {
        assertEq(marketplace.getCurrentNonceForAddress(alice), 0);

        marketplace.incrementCurrentNonceForAddress(alice);

        assertEq(marketplace.getCurrentNonceForAddress(alice), 1);
    }

    function testFulfillAskERC721Order() public {

        uint256 startingAmount = 100;
        uint256 tokenPrice = 20;
        uint256 tokenId = 0;
        
        Orders.Order memory order = setUpBobAskERC721Order();

        // Bob approves the marketplace to transfer token 0 for him
        vm.prank(bob);
        test721_1.approve(address(marketplace), tokenId);
        
        // Alice approves marketplace to send ERC20 tokens for her
        vm.startPrank(alice);
        token1.approve(address(marketplace), tokenPrice);
        
        // We expect an order fulfilled emit
        vm.expectEmit(true, true, false, false);
        emit OrderFulfilled(bob, alice, address(test721_1), 0, 1, address(token1), 20);

        // Alice fulfills bobs order
        marketplace.fulfillOrder(order);

        // Assert that alice got the ERC721 token and bob the ERC20 tokens
        assertBobAskERC721OrderFulfilled(startingAmount, tokenPrice);
    }

    function testFulfillBidERC721Order() public {

        uint256 startingAmount = 100;
        uint256 tokenPrice = 20;
        uint256 tokenId = 0;
        
        Orders.Order memory order = setUpBobBidERC721Order();

        // Alice approves the marketplace to transfer token 0 for her
        vm.prank(alice);
        test721_1.approve(address(marketplace), tokenId);
        
        // Bob approves marketplace to send ERC20 tokens for her
        vm.startPrank(bob);
        token1.approve(address(marketplace), tokenPrice);
        
        // We expect an order fulfilled emit
        vm.expectEmit(true, true, false, false);
        emit OrderFulfilled(alice, bob, address(test721_1), 0, 1, address(token1), 20);

        vm.stopPrank();

        // Alice fulfills bobs bid order
        vm.prank(alice);
        marketplace.fulfillOrder(order);

        // Assert that alice got the ERC721 token and bob the ERC20 tokens
        assertBobBidERC721OrderFulfilled(startingAmount, tokenPrice);
    }

    function testFulfillAskERC1155Order() public {

        uint256 startingAmount = 100;
        uint256 tokenPrice = 20;
        uint256 tokenId = 0;
        
        Orders.Order memory order = setUpBobBidERC1155Order();

        // Bob approves the marketplace to transfer token 0 for him
        vm.prank(bob);
        test1155_1.setApprovalForAll(address(marketplace), true);
        
        // Alice approves marketplace to send ERC20 tokens for her
        vm.startPrank(alice);
        token1.approve(address(marketplace), tokenPrice);
        
        // We expect an order fulfilled emit
        vm.expectEmit(true, true, false, false);
        emit OrderFulfilled(bob, alice, address(test721_1), 0, 10, address(token1), 20);

        // Alice fulfills bobs order
        marketplace.fulfillOrder(order);

        // Assert that alice got the ERC721 token and bob the ERC20 tokens
        assertBobBidERC1155OrderFulfilled(startingAmount, tokenPrice);
    }

    function testCancelAllOrdersForSender() public {

        uint256 startingAmount = 100;
        uint256 tokenPrice = 20;
        uint256 tokenId = 0;

        Orders.Order memory order = setUpBobAskERC721Order();
        order.nonce = 1;

        // Bob approves the marketplace to transfer token 0 for him
        vm.startPrank(bob);
        test721_1.approve(address(marketplace), tokenId);
        marketplace.cancelAllOrdersForSender(10);
        vm.stopPrank();

        // Alice approves marketplace to send ERC20 tokens for her
        vm.startPrank(alice);
        token1.approve(address(marketplace), tokenPrice);

        // Assert that alice got the ERC721 token and bob the ERC20 tokens
        vm.expectRevert(Marketplace.InvalidNonce.selector);
        marketplace.fulfillOrder(order);   
    }

    function testCancelAllOrdersForSenderBelowCurrent() public {

        uint256 startingAmount = 100;
        uint256 tokenPrice = 20;
        uint256 tokenId = 0;

        Orders.Order memory order = setUpBobAskERC721Order();
        
        order.nonce = 11; 

        // Bob approves the marketplace to transfer token 0 for him
        vm.startPrank(bob);
        test721_1.approve(address(marketplace), tokenId);

        // We will cancel orders up to 10, so this order should still go through
        marketplace.cancelAllOrdersForSender(10);
        vm.stopPrank();

        // Alice approves marketplace to send ERC20 tokens for her
        vm.startPrank(alice);
        token1.approve(address(marketplace), tokenPrice);

        marketplace.fulfillOrder(order);

        // Assert that alice got the ERC721 token and bob the ERC20 tokens
        assertBobAskERC721OrderFulfilled(startingAmount, tokenPrice);
    }

    function testCancelMultipleOrders() public {

        uint256 tokenPrice = 20;
        uint256 tokenId = 0;

        Orders.Order memory order = setUpBobAskERC721Order();
        order.nonce = 10;

        // Bob approves the marketplace to transfer token 0 for him
        vm.startPrank(bob);
        test721_1.approve(address(marketplace), tokenId);
        
        uint256[] memory noncesToCancel = new uint256[](1);
        noncesToCancel[0] = 10;
        marketplace.cancelMultipleOrders(noncesToCancel);
        vm.stopPrank();
        
        // Alice approves marketplace to send ERC20 tokens for her
        vm.startPrank(alice);
        token1.approve(address(marketplace), tokenPrice);

        vm.expectRevert(Marketplace.InvalidNonce.selector);
        marketplace.fulfillOrder(order);

    }

    function testOrderExpired() public {
        uint256 startingAmount = 100;
        uint256 tokenPrice = 20;
        uint256 tokenId = 0;
        
        Orders.Order memory order = setUpBobAskERC721Order();
        order.endTime = FAR_PAST_TIMESTAMP;
        order.startTime = FAR_PAST_TIMESTAMP;
        
        // Bob approves the marketplace to transfer token 0 for him
        vm.prank(bob);
        test721_1.approve(address(marketplace), tokenId);
        
        // Alice approves marketplace to send ERC20 tokens for her
        vm.startPrank(alice);
        token1.approve(address(marketplace), tokenPrice);

        // Alice fulfills bobs order
        vm.expectRevert(Marketplace.OrderExpired.selector);
        marketplace.fulfillOrder(order);
    }

    function testOrderNotActive() public {
        uint256 startingAmount = 100;
        uint256 tokenPrice = 20;
        uint256 tokenId = 0;
        
        Orders.Order memory order = setUpBobAskERC721Order();
        order.startTime = FAR_FUTURE_TIMESTAMP;
        
        // Bob approves the marketplace to transfer token 0 for him
        vm.prank(bob);
        test721_1.approve(address(marketplace), tokenId);
        
        // Alice approves marketplace to send ERC20 tokens for her
        vm.startPrank(alice);
        token1.approve(address(marketplace), tokenPrice);

        // Alice fulfills bobs order, order fails because of start time
        vm.expectRevert(Marketplace.OrderNotActive.selector);
        marketplace.fulfillOrder(order);

    }

}
