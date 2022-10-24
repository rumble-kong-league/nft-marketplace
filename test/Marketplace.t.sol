// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";

import "../src/Marketplace.sol";
import "../src/interfaces/IMarketplaceErrors.sol";
import "../test/TestERC20.sol";
import "../test/TestERC721.sol";
import "../test/TestTokenMinter.sol";

contract MarketplaceTest is TestTokenMinter {
    using Orders for Orders.Order;

    Marketplace marketplace;

    uint256 constant ETHEREUM_CHAIN_ID = 1;
    uint256 constant FAR_PAST_TIMESTAMP = 0;
    uint256 constant FAR_FUTURE_TIMESTAMP = 3664561158;

    // Default values
    uint256 STARTING_ERC20_AMOUNT = 100;
    uint256 DEFAULT_TOKEN_PRICE = 20;
    uint256 DEFAULT_TOKEN_ID = 0;
    uint256 DEFAULT_NONCE = 0;
    uint256 DEFAULT_TOKEN_AMOUNT = 1;

    event OrderFulfilled(
        address indexed from, address indexed to, address indexed collection, uint256 tokenId, uint256 amount, address currency, uint256 price
    );
    event Approval(address owner, address spender, uint256 value);

    function setUp() public override {
        super.setUp();
        marketplace = new Marketplace();
        marketplace.setProtocolFee(0);
        vm.chainId(ETHEREUM_CHAIN_ID);
    }

    function testIncrementNonceForContract() public {
        assertEq(marketplace.getCurrentNonceForAddress(alice), 0);
        assertEq(marketplace.getCurrentMinNonceForAddress(alice), 0);

        marketplace.incrementCurrentNonceForAddress(alice);

        assertEq(marketplace.getCurrentNonceForAddress(alice), 1);
        assertEq(marketplace.getCurrentMinNonceForAddress(alice), 0);
    }

    function testFulfillAskERC721Order() public {
        Orders.Order memory order = setUpBobAskERC721Order();

        // We expect an order fulfilled emit
        vm.expectEmit(true, true, true, true);
        emit OrderFulfilled(bob, alice, address(test721_1), 0, 1, address(token1), 20);

        // Alice fulfills bobs order
        vm.prank(alice);
        marketplace.fulfillOrder(order);

        // Assert that alice got the ERC721 token and bob the ERC20 tokens
        assertBobAskERC721OrderFulfilled();
    }

    function testFulfillBidERC721Order() public {
        Orders.Order memory order = setUpBobBidERC721Order();

        // We expect an order fulfilled emit
        vm.expectEmit(true, true, true, true);
        emit OrderFulfilled(alice, bob, address(test721_1), 0, 1, address(token1), 20);

        // Alice fulfills bobs bid order
        vm.prank(alice);
        marketplace.fulfillOrder(order);

        // Assert that alice got the ERC721 token and bob the ERC20 tokens
        assertBobBidERC721OrderFulfilled();
        assertEq(marketplace.getIsUserOrderNonceExecutedOrCanceled(bob, DEFAULT_TOKEN_ID), true);

    }

    function testFulfillAskERC1155Order() public {
        Orders.Order memory order = setUpBobAskERC1155Order();

        // We expect an order fulfilled emit
        vm.expectEmit(true, true, false, false);
        emit OrderFulfilled(bob, alice, address(test1155_1), 0, 10, address(token1), 20);

        // Alice fulfills bobs order
        vm.prank(alice);
        marketplace.fulfillOrder(order);

        // Assert that alice got the ERC721 token and bob the ERC20 tokens
        assertBobAskERC1155OrderFulfilled();
    }

    function testInvalidOrderSigner() public {
        Orders.Order memory order = setUpBobAskERC1155Order();
        order.signer = address(0);

        // Alice fulfills bobs order which fails due to an invalid signer
        vm.prank(alice);
        vm.expectRevert(IMarketplaceErrors.InvalidSigner.selector);
        marketplace.fulfillOrder(order);
    }

    function testInvalidParamaterS() public {
        Orders.Order memory order = setUpBobAskERC1155Order();
        order.s = bytes32(uint256(0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0 + 1));
        
        // Alice fulfills bobs order which fails due to an invalid signer
        vm.prank(alice);
        vm.expectRevert(SignatureChecker.InvalidParameterS.selector);
        marketplace.fulfillOrder(order);
    }

    function testInvalidParamaterV() public {
        Orders.Order memory order = setUpBobAskERC1155Order();
        order.v = 3;
        
        // Alice fulfills bobs order which fails due to an invalid signer
        vm.prank(alice);
        vm.expectRevert(SignatureChecker.InvalidParameterV.selector);
        marketplace.fulfillOrder(order);
    }

    function testInterfaceNotSupported() public {
        Orders.Order memory order = setUpBobAskERC1155Order();

        // Set address to a random collection that is not ERC20 or ERC1155
        order.collection = address(0x9df89266e11A6e018A22d3f542fBF54a4Ef56dd5); 
        
        // Alice fulfills bobs order which fails due to an invalid signer
        vm.prank(alice);
        vm.expectRevert(IMarketplaceErrors.InterfaceNotSupported.selector);
        marketplace.fulfillOrder(order);
    }
    
    function testInvalidChain() public {
        // Set chainId to a different value
        vm.chainId(2);

        Orders.Order memory order = setUpBobAskERC1155Order();
        
        // Alice fulfills bobs order which fails due to an invalid signer
        vm.prank(alice);
        vm.expectRevert(IMarketplaceErrors.InvalidChain.selector);
        marketplace.fulfillOrder(order);

        // Set chainId back to default value
        vm.chainId(ETHEREUM_CHAIN_ID);
        
    }
    
    function testCancelAllOrdersForSender() public {
        Orders.Order memory order = setUpBobAskERC721Order();

        // Set nonce and recalculate signature
        order.nonce = 1;
        (order.r, order.s, order.v) = getSignatureComponents(marketplace.getDomainSeparator(), bobPk, order.hash());

        // Bob cancels all orders up until nonce 10
        vm.prank(bob);
        marketplace.cancelAllOrdersForSender(10);

        // We expect the order nonce to be invalid when alice tries to fulfill bobs order
        vm.expectRevert(IMarketplaceErrors.InvalidNonce.selector);
        vm.prank(alice);
        marketplace.fulfillOrder(order);
    }

    function testCancelAllOrdersForSenderBelowCurrent() public {

        Orders.Order memory order = setUpBobAskERC721Order();
        order.nonce = 11;
        (order.r, order.s, order.v) = getSignatureComponents(marketplace.getDomainSeparator(), bobPk, order.hash());

        // Bob cancels all orders up until nonce 10
        vm.prank(bob);
        marketplace.cancelAllOrdersForSender(10);

        // Alice fulfills bobs order
        vm.prank(alice);
        marketplace.fulfillOrder(order);

        // Order should still be successfully fulfilled
        assertBobAskERC721OrderFulfilled();
        assertEq(marketplace.getIsUserOrderNonceExecutedOrCanceled(bob, 11), true);

    }

    function testCancelMultipleOrders() public {
        Orders.Order memory order = setUpBobAskERC721Order();
        order.nonce = 10;
        (order.r, order.s, order.v) = getSignatureComponents(marketplace.getDomainSeparator(), bobPk, order.hash());

        // Cancel all orders up until nonce 10
        uint256[] memory noncesToCancel = new uint256[](1);
        noncesToCancel[0] = 10;
        vm.prank(bob);
        marketplace.cancelMultipleOrders(noncesToCancel);
        
        // We expect the orders nonce to be invalid
        vm.expectRevert(IMarketplaceErrors.InvalidNonce.selector);
        vm.prank(alice);
        marketplace.fulfillOrder(order);
    }

    function testInvalidSigner() public {
        Orders.Order memory order = setUpBobAskERC721Order();
        order.r = "";

        // Alice fulfills bobs order
        vm.prank(alice);
        vm.expectRevert(IMarketplaceErrors.InvalidSigner.selector);
        marketplace.fulfillOrder(order);

    }

    function testOrderExpired() public {
        Orders.Order memory order = setUpBobAskERC721Order();
        order.endTime = FAR_PAST_TIMESTAMP;

        // Sign again sicne we changed the order data
        (order.r, order.s, order.v) = getSignatureComponents(marketplace.getDomainSeparator(), bobPk, order.hash());

        // We expect the order to be expired since the end time is in the past
        vm.expectRevert(IMarketplaceErrors.OrderExpired.selector);
        marketplace.fulfillOrder(order);
    }

    function testOrderNotActive() public {
        Orders.Order memory order = setUpBobAskERC721Order();
        order.startTime = FAR_FUTURE_TIMESTAMP;

        // Sign again since we changed the order data
        (order.r, order.s, order.v) = getSignatureComponents(marketplace.getDomainSeparator(), bobPk, order.hash());

        // We expect order not to be active because start time is in the future
        vm.expectRevert(IMarketplaceErrors.OrderNotActive.selector);
        marketplace.fulfillOrder(order);
    }

    function testProtocolFee() public {
        // Set protocol fee to 50%
        marketplace.setProtocolFee(5000); 

        // Random address as protocol fee reciever
        address protocolFeeReciever = 0xda84BEe8814F024B81754cbDe9c603440cF92D0B;
        marketplace.setProtocolFeeReciever(protocolFeeReciever);

        Orders.Order memory order = setUpBobAskERC721Order();

        // We expect an order fulfilled emit
        vm.expectEmit(true, true, true, true);
        emit OrderFulfilled(bob, alice, address(test721_1), 0, 1, address(token1), 20);

        // Alice fulfills bobs ask order
        vm.prank(alice);
        marketplace.fulfillOrder(order);

        assertEq(test721_1.balanceOf(alice), 1);
        assertEq(test721_1.balanceOf(bob), 0);
        assertEq(token1.balanceOf(alice), STARTING_ERC20_AMOUNT - DEFAULT_TOKEN_PRICE);
        assertEq(token1.balanceOf(bob), STARTING_ERC20_AMOUNT + DEFAULT_TOKEN_PRICE / 2);
        assertEq(token1.balanceOf(protocolFeeReciever), order.price / 2);
    }

    function testProtocolFeeNullAddress() public {
        // Set protocol fee to 50%
        marketplace.setProtocolFee(5000); 

        // Null address as protocol fee reciever
        address protocolFeeReciever = address(0x0);
        marketplace.setProtocolFeeReciever(protocolFeeReciever);

        Orders.Order memory order = setUpBobAskERC721Order();

        // Alice fulfills bobs ask order
        vm.prank(alice);
        marketplace.fulfillOrder(order);

        // This assert is the same as if there were no fees
        assertBobAskERC721OrderFulfilled();
    }

    function testFulfillAskERC721Order1271Signer() public {
        Orders.Order memory order = setUpBobAskERC721Order();

        // Send ERC721 to ERC1271 contract
        test721_1.safeTransferFrom(bob, address(test1271_1), DEFAULT_TOKEN_ID);
        order.signer = address(test1271_1);

        // ERC1271 must approve marketplace
        vm.prank(address(test1271_1));
        test721_1.approve(address(marketplace), DEFAULT_TOKEN_ID);

        // We expect an order fulfilled emit
        vm.expectEmit(true, true, true, true);
        emit OrderFulfilled(address(test1271_1), alice, address(test721_1), 0, 1, address(token1), 20);

        // Alice fulfills the order
        vm.prank(alice);
        marketplace.fulfillOrder(order);

        // Assert that alice got the ERC721 token and the signer contract the ERC20 tokens
        assertEq(test721_1.balanceOf(alice), 1);
        assertEq(test721_1.balanceOf(bob), 0);
        assertEq(token1.balanceOf(alice), STARTING_ERC20_AMOUNT - DEFAULT_TOKEN_PRICE);
        assertEq(token1.balanceOf(address(test1271_1)), DEFAULT_TOKEN_PRICE);
    }

    function assertInitialTokenBalances(address seller, address buyer) internal {
        assertEq(test721_1.balanceOf(buyer), 0);
        assertEq(test721_1.balanceOf(seller), 1);
        assertEq(token1.balanceOf(seller), STARTING_ERC20_AMOUNT);
        assertEq(token1.balanceOf(buyer), STARTING_ERC20_AMOUNT);
    }

    function setUpBobAskERC721Order() internal returns (Orders.Order memory) {
        // Bob mints an ERC721 token
        test721_1.mint(bob, 0);
        assertInitialTokenBalances(bob, alice);
        
        setApprovals({
            addressToApproveErc721 : bob,
            addressToApproveErc20 : alice
        });

        // Bob creates an order to sell his nft for 20 ERC20 tokens
        Orders.Order memory order = Orders.Order({
            isAsk: true,
            signer: bob,
            nonce: DEFAULT_NONCE,
            startTime: FAR_PAST_TIMESTAMP,
            endTime: FAR_FUTURE_TIMESTAMP,
            collection: address(test721_1),
            tokenId: DEFAULT_TOKEN_ID,
            amount: DEFAULT_TOKEN_AMOUNT,
            price: DEFAULT_TOKEN_PRICE,
            currency: address(token1),
            v : 0,
            r : "",
            s : ""
        });

        (order.r, order.s, order.v) = getSignatureComponents(marketplace.getDomainSeparator(), bobPk, order.hash());

        return order;
    }

    function setUpBobBidERC721Order() internal returns (Orders.Order memory) {
        // Alice mints an ERC721 token
        test721_1.mint(alice, 0);
        assertInitialTokenBalances(alice, bob);
        setApprovals({
            addressToApproveErc721 : alice,
            addressToApproveErc20 : bob
        });
        // Bob creates a bid order to buy alices NFT for 20 ERC20 tokens
        Orders.Order memory order = Orders.Order({
            isAsk: false,
            signer: bob,
            nonce: DEFAULT_NONCE,
            startTime: FAR_PAST_TIMESTAMP,
            endTime: FAR_FUTURE_TIMESTAMP,
            collection: address(test721_1),
            tokenId: DEFAULT_TOKEN_ID,
            amount: DEFAULT_TOKEN_AMOUNT,
            price: DEFAULT_TOKEN_PRICE,
            currency: address(token1),
            v : 0,
            r : "",
            s : ""
        });

        (order.r, order.s, order.v) = getSignatureComponents(marketplace.getDomainSeparator(), bobPk, order.hash());

        return order;
    }

    function setUpBobAskERC1155Order() internal returns (Orders.Order memory) {
        // Bob mints an ERC721 token
        test1155_1.mint(bob, 0, 10);
        assertEq(test1155_1.balanceOf(bob, 0), 10);
        assertEq(test1155_1.balanceOf(alice, 0 ), 0);
        assertEq(token1.balanceOf(bob), STARTING_ERC20_AMOUNT);
        assertEq(token1.balanceOf(alice), STARTING_ERC20_AMOUNT);

        // A approves the marketplace to transfer token 0 on behalf of A
        vm.prank(bob);
        test1155_1.setApprovalForAll(address(marketplace), true);

        // B approves marketplace to send ERC20 tokens on behalf of B
        vm.prank(alice);
        token1.approve(address(marketplace), DEFAULT_TOKEN_PRICE);

        // Bob creates an order to sell his nft for 20 ERC20 tokens
        Orders.Order memory order = Orders.Order({
            isAsk: true,
            signer: bob,
            nonce: 0,
            startTime: FAR_PAST_TIMESTAMP,
            endTime: FAR_FUTURE_TIMESTAMP,
            collection: address(test1155_1),
            tokenId: DEFAULT_TOKEN_ID,
            amount: 10,
            price: DEFAULT_TOKEN_PRICE,
            currency: address(token1),
            v : 0,
            r : "",
            s : ""
        });

        (order.r, order.s, order.v) = getSignatureComponents(marketplace.getDomainSeparator(), bobPk, order.hash());
        return order;
    }

    function setApprovals(address addressToApproveErc721, address addressToApproveErc20) internal {
        // A approves the marketplace to transfer token 0 on behalf of A
        vm.prank(addressToApproveErc721);
        test721_1.approve(address(marketplace), DEFAULT_TOKEN_ID);

        // B approves marketplace to send ERC20 tokens on behalf of B
        vm.prank(addressToApproveErc20);
        token1.approve(address(marketplace), DEFAULT_TOKEN_PRICE);
    }

    function assertBobAskERC721OrderFulfilled() internal {
        assertEq(test721_1.balanceOf(alice), 1);
        assertEq(test721_1.balanceOf(bob), 0);
        assertEq(token1.balanceOf(alice), STARTING_ERC20_AMOUNT - DEFAULT_TOKEN_PRICE);
        assertEq(token1.balanceOf(bob), STARTING_ERC20_AMOUNT + DEFAULT_TOKEN_PRICE);
    }

    function assertBobBidERC721OrderFulfilled() internal {
        assertEq(test721_1.balanceOf(bob), 1);
        assertEq(test721_1.balanceOf(alice), 0);
        assertEq(token1.balanceOf(bob), STARTING_ERC20_AMOUNT - DEFAULT_TOKEN_PRICE);
        assertEq(token1.balanceOf(alice), STARTING_ERC20_AMOUNT + DEFAULT_TOKEN_PRICE);
    }

    function assertBobAskERC1155OrderFulfilled() internal {
        assertEq(test1155_1.balanceOf(bob, 0), 0);
        assertEq(test1155_1.balanceOf(alice, 0), 10);
        assertEq(token1.balanceOf(alice), STARTING_ERC20_AMOUNT - DEFAULT_TOKEN_PRICE);
        assertEq(token1.balanceOf(bob), STARTING_ERC20_AMOUNT + DEFAULT_TOKEN_PRICE);
        assertEq(marketplace.getIsUserOrderNonceExecutedOrCanceled(bob, 0), true);
    }

    function getSignatureComponents(bytes32 domainSeparator, uint256 _pkOfSigner, bytes32 _orderHash)
        internal
        returns (bytes32, bytes32, uint8)
    {
        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(_pkOfSigner, keccak256(abi.encodePacked(bytes2(0x1901), domainSeparator, _orderHash)));
        return (r, s, v);
    }
}
