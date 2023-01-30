// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";

import "../src/Marketplace.sol";
import "../src/MarketplaceProxy.sol";
import "../src/interfaces/IMarketplaceErrors.sol";
import "../test/TestERC20.sol";
import "../test/TestERC721.sol";
import "../test/TestTokenMinter.sol";

contract MarketplaceTest is TestTokenMinter {
    using Orders for Orders.Order;

    Marketplace marketplace;
    ProxyAdmin proxyAdmin;
    MarketplaceProxy proxy;

    address owner;

    uint256 constant ETHEREUM_CHAIN_ID = 1;
    uint256 constant FAR_PAST_TIMESTAMP = 0;
    uint256 constant FAR_FUTURE_TIMESTAMP = 3664561158;

    // Default values
    uint256 STARTING_ERC20_AMOUNT = 100;
    uint256 DEFAULT_TOKEN_PRICE = 20;
    uint256 DEFAULT_TOKEN_ID = 0;
    uint256 DEFAULT_NONCE = 0;
    uint256 DEFAULT_TOKEN_AMOUNT = 1;

    // Used for merkle proofs
    bytes32[] hashes;
    bytes32[] proof;

    event OrderFulfilled(
        address indexed from,
        address indexed to,
        address indexed collection,
        uint256 tokenId,
        uint256 amount,
        address currency,
        uint256 price
    );
    event Approval(address owner, address spender, uint256 value);

    function setUp() public override {
        vm.chainId(ETHEREUM_CHAIN_ID);
        owner = vm.addr(1);
        super.setUp();

        vm.startPrank(owner);

        // Deploy the implementation contract        
        Marketplace marketplace1 = new Marketplace();

        // Deploy the proxy admin contract
        proxyAdmin = new ProxyAdmin();
        
        // Deploy the proxy contract
        // bytes memory data = abi.encodeWithSignature("initialize()");
        proxy = new MarketplaceProxy(address(marketplace1), address(proxyAdmin), '');
        

        vm.stopPrank();

        vm.startPrank(owner);
        marketplace1.initialize();
        marketplace1.setProtocolFee(0);
        marketplace = Marketplace(proxyAdmin.getProxyImplementation(proxy));
        vm.stopPrank();


    }

    function testFulfillAskERC721Order() public {
        Orders.Order memory order = setUpBobAskERC721Order(DEFAULT_TOKEN_ID, DEFAULT_NONCE);

        // We expect an order fulfilled emit
        vm.expectEmit(true, true, true, true);
        emit OrderFulfilled(bob, alice, address(test721_1), 0, 1, address(token1), 20);

        // Alice fulfills bobs order
        vm.prank(alice);

        marketplace.fulfillOrder(wrapInArray(order));

        // Assert that alice got the ERC721 token and bob the ERC20 tokens
        assertBobAskERC721OrderFulfilled();
    }

    function testFulfillMultipleAskERC721Orders() public {
        Orders.Order memory order1 = setUpBobAskERC721Order(DEFAULT_TOKEN_ID, DEFAULT_NONCE);
        Orders.Order memory order2 = setUpBobAskERC721Order(DEFAULT_TOKEN_ID + 1, DEFAULT_NONCE + 1);

        // We expect 2 orders to be fulfilled, with just a difference in the token id
        vm.expectEmit(true, true, true, true);
        emit OrderFulfilled(bob, alice, address(test721_1), DEFAULT_TOKEN_ID, 1, address(token1), DEFAULT_TOKEN_PRICE);
        vm.expectEmit(true, true, true, true);
        emit OrderFulfilled(
            bob, alice, address(test721_1), DEFAULT_TOKEN_ID + 1, 1, address(token1), DEFAULT_TOKEN_PRICE
            );

        // Wrap orders in array
        Orders.Order[] memory orders = new Orders.Order[](2);
        orders[0] = order1;
        orders[1] = order2;

        // Alice fulfills bobs order
        vm.prank(alice);
        marketplace.fulfillOrder(orders);

        // Assert that alice got the 2xERC721 token and bob the 2xprice ERC20 tokens
        assertEq(test721_1.balanceOf(alice), 2);
        assertEq(test721_1.balanceOf(bob), 0);
        assertEq(token1.balanceOf(alice), STARTING_ERC20_AMOUNT - DEFAULT_TOKEN_PRICE * 2);
        assertEq(token1.balanceOf(bob), STARTING_ERC20_AMOUNT + DEFAULT_TOKEN_PRICE * 2);
    }

    function testFulfillBidERC721Order() public {
        Orders.Order memory order = setUpBobBidERC721Order(DEFAULT_TOKEN_ID, DEFAULT_NONCE);

        // We expect an order fulfilled emit
        vm.expectEmit(true, true, true, true);
        emit OrderFulfilled(alice, bob, address(test721_1), 0, 1, address(token1), 20);

        // Alice fulfills bobs bid order
        vm.prank(alice);
        marketplace.fulfillOrder(wrapInArray(order));

        // Assert that alice got the ERC721 token and bob the ERC20 tokens
        assertBobBidERC721OrderFulfilled();
        assertEq(marketplace.getIsUserOrderNonceExecutedOrCanceled(bob, DEFAULT_TOKEN_ID), true);
    }

    function testFulfillAskERC1155Order() public {
        Orders.Order memory order = setUpBobAskERC1155Order(DEFAULT_TOKEN_ID, DEFAULT_NONCE);

        // We expect an order fulfilled emit
        vm.expectEmit(true, true, false, false);
        emit OrderFulfilled(bob, alice, address(test1155_1), 0, 10, address(token1), 20);

        // Alice fulfills bobs order
        vm.prank(alice);
        marketplace.fulfillOrder(wrapInArray(order));

        // Assert that alice got the ERC721 token and bob the ERC20 tokens
        assertBobAskERC1155OrderFulfilled();
    }

    function testInvalidOrderSigner() public {
        Orders.Order memory order = setUpBobAskERC1155Order(DEFAULT_TOKEN_ID, DEFAULT_NONCE);
        order.signer = address(0);

        // Alice fulfills bobs order which fails due to an invalid signer
        vm.prank(alice);
        vm.expectRevert(IMarketplaceErrors.InvalidSigner.selector);
        marketplace.fulfillOrder(wrapInArray(order));
    }

    function testInvalidOrderSignature() public {
        Orders.Order memory order = setUpBobAskERC1155Order(DEFAULT_TOKEN_ID, DEFAULT_NONCE);
        order.collection = vm.addr(0xb0b); // random address will change order hash and make signature fail

        // Alice fulfills bobs order which fails due to an invalid signer
        vm.prank(alice);
        vm.expectRevert(IMarketplaceErrors.InvalidSignature.selector);
        marketplace.fulfillOrder(wrapInArray(order));
    }

    function testInvalidParamaterS() public {
        Orders.Order memory order = setUpBobAskERC1155Order(DEFAULT_TOKEN_ID, DEFAULT_NONCE);
        order.s = bytes32(uint256(0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0 + 1));

        // Alice fulfills bobs order which fails due to an invalid signer
        vm.prank(alice);
        vm.expectRevert(SignatureChecker.InvalidParameterS.selector);
        marketplace.fulfillOrder(wrapInArray(order));
    }

    function testInvalidParamaterV() public {
        Orders.Order memory order = setUpBobAskERC1155Order(DEFAULT_TOKEN_ID, DEFAULT_NONCE);
        order.v = 3;

        // Alice fulfills bobs order which fails due to an invalid signer
        vm.prank(alice);
        vm.expectRevert(SignatureChecker.InvalidParameterV.selector);
        marketplace.fulfillOrder(wrapInArray(order));
    }

    function testInterfaceNotSupported() public {
        Orders.Order memory order = setUpBobAskERC1155Order(DEFAULT_TOKEN_ID, DEFAULT_NONCE);

        // Set collection to a random collection that is not ERC20 or ERC1155
        order.collection = address(0x9df89266e11A6e018A22d3f542fBF54a4Ef56dd5);

        // Recalculate signature with new collection address
        (order.r, order.s, order.v) = getSignatureComponents(marketplace.getDomainSeparator(), bobPk, order.hash());

        // Alice fulfills bobs order which fails due to a not supported interface
        vm.prank(alice);

        vm.expectRevert(IMarketplaceErrors.InterfaceNotSupported.selector);
        marketplace.fulfillOrder(wrapInArray(order));
    }

    function testCancelAllOrdersForSender() public {
        Orders.Order memory order = setUpBobAskERC721Order(DEFAULT_TOKEN_ID, DEFAULT_NONCE);

        // Set nonce and recalculate signature
        order.nonce = 1;
        (order.r, order.s, order.v) = getSignatureComponents(marketplace.getDomainSeparator(), bobPk, order.hash());

        // Bob cancels all orders up until nonce 10
        vm.prank(bob);
        marketplace.cancelAllOrdersForSender(10);

        // We expect the order nonce to be invalid when alice tries to fulfill bobs order
        vm.expectRevert(IMarketplaceErrors.InvalidNonce.selector);
        vm.prank(alice);
        marketplace.fulfillOrder(wrapInArray(order));
    }

    function testCancelAllOrdersForSenderInvalidNonce() public {
        // Bob cancels all orders up until nonce 10
        vm.prank(bob);
        marketplace.cancelAllOrdersForSender(10);

        // We expect revert because 5 < 10
        vm.prank(bob);
        vm.expectRevert(IMarketplaceErrors.InvalidNonce.selector);
        marketplace.cancelAllOrdersForSender(5);
    }

    function testCancelAllOrdersForSenderNonceTooHigh() public {
        // We expect rever because 600000 > 0 + 500000
        vm.prank(bob);
        vm.expectRevert(IMarketplaceErrors.InvalidNonce.selector);
        marketplace.cancelAllOrdersForSender(600000);
    }

    function testCancelAllOrdersForSenderBelowCurrent() public {
        Orders.Order memory order = setUpBobAskERC721Order(DEFAULT_TOKEN_ID, DEFAULT_NONCE);
        order.nonce = 11;
        (order.r, order.s, order.v) = getSignatureComponents(marketplace.getDomainSeparator(), bobPk, order.hash());

        // Bob cancels all orders up until nonce 10
        vm.prank(bob);
        marketplace.cancelAllOrdersForSender(10);

        // Alice fulfills bobs order
        vm.prank(alice);
        marketplace.fulfillOrder(wrapInArray(order));

        // Order should still be successfully fulfilled
        assertBobAskERC721OrderFulfilled();
        assertEq(marketplace.getIsUserOrderNonceExecutedOrCanceled(bob, 11), true);
        assertEq(marketplace.getCurrentMinNonceForAddress(bob), 10);
    }

    function testCancelMultipleOrders() public {
        Orders.Order memory order = setUpBobAskERC721Order(DEFAULT_TOKEN_ID, DEFAULT_NONCE);
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
        marketplace.fulfillOrder(wrapInArray(order));
    }

    uint256[] nonceArray; // init empty storage array

    function testCancelMultipleOrdersEmptyArray() public {
        vm.prank(bob);
        vm.expectRevert(IMarketplaceErrors.InvalidNonce.selector);
        marketplace.cancelMultipleOrders(nonceArray);
    }

    function testCancelMultipleOrdersNonceTooLow() public {
        // Bob cancels all orders up until nonce 10
        vm.prank(bob);
        marketplace.cancelAllOrdersForSender(10);

        // We expect revert because we will try to cancel again order below
        // bobs minUserNonce which is 10 now
        uint256[] memory faultyNonceArray = new uint256[](1);
        faultyNonceArray[0] = 4;
        vm.prank(bob);
        vm.expectRevert(IMarketplaceErrors.InvalidNonce.selector);
        marketplace.cancelMultipleOrders(faultyNonceArray);
    }

    function testInvalidSigner() public {
        Orders.Order memory order = setUpBobAskERC721Order(DEFAULT_TOKEN_ID, DEFAULT_NONCE);
        order.r = "";

        // Alice fulfills bobs order
        vm.prank(alice);
        vm.expectRevert(IMarketplaceErrors.InvalidSigner.selector);
        marketplace.fulfillOrder(wrapInArray(order));
    }

    function testOrderExpired() public {
        Orders.Order memory order = setUpBobAskERC721Order(DEFAULT_TOKEN_ID, DEFAULT_NONCE);
        order.endTime = FAR_PAST_TIMESTAMP;

        // Sign again sicne we changed the order data
        (order.r, order.s, order.v) = getSignatureComponents(marketplace.getDomainSeparator(), bobPk, order.hash());

        // We expect the order to be expired since the end time is in the past
        vm.expectRevert(IMarketplaceErrors.OrderExpired.selector);
        marketplace.fulfillOrder(wrapInArray(order));
    }

    function testOrderNotActive() public {
        Orders.Order memory order = setUpBobAskERC721Order(DEFAULT_TOKEN_ID, DEFAULT_NONCE);
        order.startTime = FAR_FUTURE_TIMESTAMP;

        // Sign again since we changed the order data
        (order.r, order.s, order.v) = getSignatureComponents(marketplace.getDomainSeparator(), bobPk, order.hash());

        // We expect order not to be active because start time is in the future
        vm.expectRevert(IMarketplaceErrors.OrderNotActive.selector);
        marketplace.fulfillOrder(wrapInArray(order));
    }

    function testProtocolFee() public {
        // Set protocol fee to 50%
        vm.prank(owner);
        marketplace.setProtocolFee(5000);

        // Random address as protocol fee reciever
        address protocolFeeReciever = 0xda84BEe8814F024B81754cbDe9c603440cF92D0B;
        vm.prank(owner);
        marketplace.setProtocolFeeReciever(protocolFeeReciever);

        Orders.Order memory order = setUpBobAskERC721Order(DEFAULT_TOKEN_ID, DEFAULT_NONCE);

        // We expect an order fulfilled emit
        vm.expectEmit(true, true, true, true);
        emit OrderFulfilled(bob, alice, address(test721_1), 0, 1, address(token1), 20);

        // Alice fulfills bobs ask order
        vm.prank(alice);
        marketplace.fulfillOrder(wrapInArray(order));

        assertEq(test721_1.balanceOf(alice), 1);
        assertEq(test721_1.balanceOf(bob), 0);
        assertEq(token1.balanceOf(alice), STARTING_ERC20_AMOUNT - DEFAULT_TOKEN_PRICE);
        assertEq(token1.balanceOf(bob), STARTING_ERC20_AMOUNT + DEFAULT_TOKEN_PRICE / 2);
        assertEq(token1.balanceOf(protocolFeeReciever), order.price / 2);
    }

    function testFulfillAskERC721Order1271Signer() public {
        Orders.Order memory order = setUpBobAskERC721Order(DEFAULT_TOKEN_ID, DEFAULT_NONCE);

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
        marketplace.fulfillOrder(wrapInArray(order));

        // Assert that alice got the ERC721 token and the signer contract the ERC20 tokens
        assertEq(test721_1.balanceOf(alice), 1);
        assertEq(test721_1.balanceOf(bob), 0);
        assertEq(token1.balanceOf(alice), STARTING_ERC20_AMOUNT - DEFAULT_TOKEN_PRICE);
        assertEq(token1.balanceOf(address(test1271_1)), DEFAULT_TOKEN_PRICE);
    }

    function testAreUserNoncesValid() public {
        // Bob cancels all orders up to 23
        vm.startPrank(bob);
        marketplace.cancelAllOrdersForSender(23);

        // Bob cancels orders with nonce 27, 39, 41 and 45
        uint256[] memory noncesToCancelBob = new uint256[](2);
        noncesToCancelBob[0] = 27;
        noncesToCancelBob[1] = 39;
        marketplace.cancelMultipleOrders(noncesToCancelBob);
        vm.stopPrank();

        // Alice cancels all orders up to 23
        vm.startPrank(alice);
        marketplace.cancelAllOrdersForSender(14);

        // Bob cancels orders with nonce 27, 39, 41 and 45
        uint256[] memory noncesToCancelAlice = new uint256[](2);
        noncesToCancelAlice[0] = 31;
        noncesToCancelAlice[1] = 34;
        marketplace.cancelMultipleOrders(noncesToCancelAlice);
        vm.stopPrank();

        // Build inpute for artUserNoncesValid
        Marketplace.UserNonce[] memory noncesToCheck = new Marketplace.UserNonce[](2);
        uint256[] memory bobNonces = new uint256[](3);
        bobNonces[0] = 11;
        bobNonces[1] = 40;
        bobNonces[2] = 39;
        noncesToCheck[0] = Marketplace.UserNonce({user: bob, nonces: bobNonces});

        uint256[] memory aliceNonces = new uint256[](3);
        aliceNonces[0] = 10;
        aliceNonces[1] = 27;
        aliceNonces[2] = 34;
        noncesToCheck[1] = Marketplace.UserNonce({user: alice, nonces: aliceNonces});

        bool[][] memory areNoncesValid = marketplace.areUserNoncesValid(noncesToCheck);

        assertEq(areNoncesValid[0][0], false);
        assertEq(areNoncesValid[0][1], true);
        assertEq(areNoncesValid[0][2], false);
        assertEq(areNoncesValid[1][0], false);
        assertEq(areNoncesValid[1][1], true);
        assertEq(areNoncesValid[1][2], false);
    }

    function testMarketplaceInactive() public {
        // Make the marketplace inactive
        vm.prank(owner);
        marketplace.toggleActive();

        // Create an order for alice to fulfill
        Orders.Order memory order = setUpBobAskERC721Order(DEFAULT_TOKEN_ID, DEFAULT_NONCE);

        // Alice fulfills bobs order
        vm.prank(alice);

        // We expect fulfillOrder to fail due to the marketplace not being active
        vm.expectRevert(IMarketplaceErrors.MarketplaceNotActive.selector);
        marketplace.fulfillOrder(wrapInArray(order));

        // Make the marketplace active again
        vm.prank(owner);
        marketplace.toggleActive();

        // Alice fulfills bobs order
        vm.prank(alice);
        marketplace.fulfillOrder(wrapInArray(order));

        // Assert that alice got the ERC721 token and bob the ERC20 tokens
        assertBobAskERC721OrderFulfilled();
    }

    function testFailFeeTransfer() public {
        Orders.Order memory order = setUpBobAskERC721Order(DEFAULT_TOKEN_ID, DEFAULT_NONCE);
        marketplace.setProtocolFee(1 ether); // Force a fee transfer failure

        // Alice fulfills bobs order
        vm.prank(alice);
        vm.expectRevert(IMarketplaceErrors.FeeTransferFailed.selector);
        marketplace.fulfillOrder(wrapInArray(order));
    }

    function testFailERC20Transfer() public {
        Orders.Order memory order = setUpBobAskERC721Order(DEFAULT_TOKEN_ID, DEFAULT_NONCE);
        order.price = 100000 ether; // Force an ERC20 transfer failure

        (order.r, order.s, order.v) = getSignatureComponents(marketplace.getDomainSeparator(), bobPk, order.hash());

        // Alice fulfills bobs order
        vm.prank(alice);
        vm.expectRevert(IMarketplaceErrors.ERC20TransferFailed.selector);
        marketplace.fulfillOrder(wrapInArray(order));
    }

    function assertInitialTokenBalances(address seller, address buyer) internal {
        assertEq(test721_1.balanceOf(buyer), 0);
        assertEq(test721_1.balanceOf(seller), 1);
        assertEq(token1.balanceOf(seller), STARTING_ERC20_AMOUNT);
        assertEq(token1.balanceOf(buyer), STARTING_ERC20_AMOUNT);
    }

    function setUpBobAskERC721Order(uint256 tokenId, uint256 nonce) internal returns (Orders.Order memory) {
        // Bob mints an ERC721 token
        test721_1.mint(bob, tokenId);

        setApprovals({
            addressToApproveErc721: bob,
            tokenId: tokenId,
            addressToApproveErc20: alice,
            erc20TokenAmount: token1.balanceOf(alice)
        });

        // Bob creates an order to sell his nft for 20 ERC20 tokens
        Orders.Order memory order = Orders.Order({
            isAsk: true,
            signer: bob,
            nonce: nonce,
            startTime: FAR_PAST_TIMESTAMP,
            endTime: FAR_FUTURE_TIMESTAMP,
            collection: address(test721_1),
            tokenId: tokenId,
            amount: DEFAULT_TOKEN_AMOUNT,
            price: DEFAULT_TOKEN_PRICE,
            currency: address(token1),
            v: 0,
            r: "",
            s: ""
        });

        (order.r, order.s, order.v) = getSignatureComponents(marketplace.getDomainSeparator(), bobPk, order.hash());

        return order;
    }

    function setUpBobBidERC721Order(uint256 tokenId, uint256 nonce) internal returns (Orders.Order memory) {
        // Alice mints an ERC721 token
        test721_1.mint(alice, tokenId);

        setApprovals({
            addressToApproveErc721: alice,
            tokenId: tokenId,
            addressToApproveErc20: bob,
            erc20TokenAmount: token1.balanceOf(alice)
        });

        // Bob creates a bid order to buy alices NFT for 20 ERC20 tokens
        Orders.Order memory order = Orders.Order({
            isAsk: false,
            signer: bob,
            nonce: nonce,
            startTime: FAR_PAST_TIMESTAMP,
            endTime: FAR_FUTURE_TIMESTAMP,
            collection: address(test721_1),
            tokenId: tokenId,
            amount: DEFAULT_TOKEN_AMOUNT,
            price: DEFAULT_TOKEN_PRICE,
            currency: address(token1),
            v: 0,
            r: "",
            s: ""
        });

        (order.r, order.s, order.v) = getSignatureComponents(marketplace.getDomainSeparator(), bobPk, order.hash());

        return order;
    }

    function setUpBobAskERC1155Order(uint256 tokenId, uint256 nonce) internal returns (Orders.Order memory) {
        // Bob mints an ERC721 token
        test1155_1.mint(bob, DEFAULT_TOKEN_ID, 10);

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
            nonce: nonce,
            startTime: FAR_PAST_TIMESTAMP,
            endTime: FAR_FUTURE_TIMESTAMP,
            collection: address(test1155_1),
            tokenId: tokenId,
            amount: 10,
            price: DEFAULT_TOKEN_PRICE,
            currency: address(token1),
            v: 0,
            r: "",
            s: ""
        });

        (order.r, order.s, order.v) = getSignatureComponents(marketplace.getDomainSeparator(), bobPk, order.hash());
        return order;
    }

    function setApprovals(
        address addressToApproveErc721,
        uint256 tokenId,
        address addressToApproveErc20,
        uint256 erc20TokenAmount
    ) internal {
        // A approves the marketplace to transfer token 0 on behalf of A
        vm.prank(addressToApproveErc721);
        test721_1.approve(address(marketplace), tokenId);

        // B approves marketplace to send ERC20 tokens on behalf of B
        vm.prank(addressToApproveErc20);
        token1.approve(address(marketplace), erc20TokenAmount);
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

    function wrapInArray(Orders.Order memory order) internal pure returns (Orders.Order[] memory) {
        Orders.Order[] memory array = new Orders.Order[](1);
        array[0] = order;
        return array;
    }

    function getSignatureComponents(bytes32 domainSeparator, uint256 _pkOfSigner, bytes32 _orderHash)
        internal
        returns (bytes32, bytes32, uint8)
    {
        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(_pkOfSigner, keccak256(abi.encodePacked(bytes2(0x1901), domainSeparator, _orderHash)));
        return (r, s, v);
    }

    function buildMerkleTree(bytes32[] storage hashArray) internal returns (bytes32[] storage) {
        uint256 count = hashArray.length; // number of leaves
        uint256 offset = 0;

        while (count > 0) {
            // Iterate 2 by 2, building the hash pairs
            for (uint256 i = 0; i < count - 1; i += 2) {
                hashArray.push(_hashPair(hashArray[offset + i], hashArray[offset + i + 1]));
            }
            offset += count;
            count = count / 2;
        }
        return hashArray;
    }

    /**
     * From MerkleProof.sol
     */
    function _hashPair(bytes32 a, bytes32 b) private pure returns (bytes32) {
        return a < b ? _efficientHash(a, b) : _efficientHash(b, a);
    }

    /**
     * From MerkleProof.sol
     */
    function _efficientHash(bytes32 a, bytes32 b) private pure returns (bytes32 value) {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x00, a)
            mstore(0x20, b)
            value := keccak256(0x00, 0x40)
        }
    }
}
