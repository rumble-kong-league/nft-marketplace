// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./interfaces/IMarketplaceErrors.sol";
import "./interfaces/IMarketplace.sol";
import {SignatureChecker} from "./libraries/SignatureChecker.sol";

// !!! When deploying on a new chain do:
// 1. generate new SALT
// !!! When deploying new version do:
// 1. generate new SALT
// 2. increment VERSION

// TODO: revert with custom Error in place of all the require

// How To Improve This Contract
// 1. Batch transfer a combination of 721s and 1155s. This
// would utilise safeBatchTransferFrom on the 1155 side.
contract Marketplace is IMarketplace, IMarketplaceErrors, Ownable, ReentrancyGuard {
    using Orders for Orders.Order;
    using ERC165Checker for address;

    bytes4 private constant IID_IERC1155 = type(IERC1155).interfaceId;
    bytes4 private constant IID_IERC721 = type(IERC721).interfaceId;

    uint256 private PROTOCOL_FEE; // 10000 = 100%
    address private PROTOCOL_FEE_RECIEVER;

    bytes32 public constant SALT = 0xcc6bba07dc72ccc06230832cb75198fc8dc757cf7b7e10f1406cbd6867ab4a34;
    // string private constant EIP712_DOMAIN = "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract,bytes32 salt)";
    bytes32 public immutable DOMAIN_SEPARATOR;

    // keeps track of user's min active nonce
    mapping(address => uint256) private userMinOrderNonce;
    // keeps track of nonces that have been executed or cancelled
    mapping(address => mapping(uint256 => bool)) private isUserOrderNonceExecutedOrCancelled;

    constructor() {
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                0xd87cd6ef79d4e2b95e15ce8abf732db51ec771f1ca2edccf22a46c729ac56472, // keccak256(bytes(EIP712_DOMAIN))
                0xc80aed6001eb579bef6ecf8ec6632ecb0c96a906bf473289ccf79e73ac90fca8, // keccak256(bytes("RKL Marketplace"))
                0xc89efdaa54c0f20c7adf612882df0950f5a951637e0307cdcb4c672f298b8bc6, // keccak256(bytes("1"))
                block.chainid,
                address(this),
                SALT
            )
        );
    }

    /**
     * @notice Fulfills an order stored off chain. Call must be made by
     * either the buyer or the seller depending if the order is an ask or a bid.
     * Order must also be signed according to the EIP-712 standard and order.signer
     * must be the address of the order.signature signer.
     * @param order The order to be fulfilled
     */
    function fulfillOrder(Orders.Order calldata order) external {
        _validateOrder(order);
        // update signer order status to true (prevents replay)
        isUserOrderNonceExecutedOrCancelled[order.signer][order.nonce] = true;
        _fulfillOrder(order);
    }

    function _validateOrder(Orders.Order calldata order) internal view {
        if (order.signer == address(0)) {
            revert InvalidSigner();
        }
        // if signed message used a different chain id than the one in DOMAIN_SEPARATOR, this
        // verification will fail
        SignatureChecker.verify(order.hash(), order.signer, order.v, order.r, order.s, DOMAIN_SEPARATOR);
        if (order.startTime > block.timestamp) {
            revert OrderNotActive();
        }
        if (order.endTime < block.timestamp) {
            revert OrderExpired();
        }
        if (
            (isUserOrderNonceExecutedOrCancelled[order.signer][order.nonce])
                || (order.nonce < userMinOrderNonce[order.signer])
        ) {
            revert InvalidNonce();
        }
    }

    function _fulfillOrder(Orders.Order calldata order) internal {
        (address seller, address buyer) = order.isAsk ? (order.signer, msg.sender) : (msg.sender, order.signer);
        _transferFeesAndFunds(buyer, seller, order.currency, order.price);
        _transferNonFungibleToken(order.collection, seller, buyer, order.tokenId, order.amount);
        emit OrderFulfilled(seller, buyer, order.collection, order.tokenId, order.amount, order.currency, order.price);
    }

    /**
     * @notice Cancel all orders below a certain nonce for a user
     * @param minNonce The nonce below which orders should be cancelled
     */
    function cancelAllOrdersForSender(uint256 minNonce) external {
        if (minNonce <= userMinOrderNonce[msg.sender]) {
            // Cancel: Order nonce lower than current
            revert InvalidNonce();
        }
        // so that the user does not input a nonce that is type(uint256).max and bricks themselves
        // from ever trading with this contract again
        if (minNonce >= userMinOrderNonce[msg.sender] + 500000) {
            // Cancel: Cannot cancel more orders
            revert InvalidNonce();
        }
        userMinOrderNonce[msg.sender] = minNonce;
        emit CancelAllOrdersForUser(msg.sender, minNonce);
    }

    /**
     * @notice Cancel multiple orders with specific nonces
     * @param orderNonces array of nonces corresponding to the orders to be cancelled
     */
    function cancelMultipleOrders(uint256[] calldata orderNonces) external {
        if (orderNonces.length <= 0) {
            // Cancel: Cannot be empty
            revert InvalidNonce();
        }
        for (uint256 i = 0; i < orderNonces.length; i++) {
            if (orderNonces[i] < userMinOrderNonce[msg.sender]) {
                // Cancel: Order nonce lower than current
                revert InvalidNonce();
            }
            isUserOrderNonceExecutedOrCancelled[msg.sender][orderNonces[i]] = true;
        }
        emit CancelMultipleOrders(msg.sender, orderNonces);
    }

    /**
     * @notice Transfer NFTs
     * @param collection address of the token collection
     * @param from address of the sender
     * @param to address of the recipient
     * @param tokenId tokenId
     * @param amount amount of tokens
     */
    function _transferNonFungibleToken(address collection, address from, address to, uint256 tokenId, uint256 amount)
        internal
        nonReentrant
    {
        if (collection.supportsInterface(IID_IERC721)) {
            IERC721(collection).safeTransferFrom(from, to, tokenId);
        } else if (collection.supportsInterface(IID_IERC1155)) {
            IERC1155(collection).safeTransferFrom(from, to, tokenId, amount, "");
        } else {
            revert InterfaceNotSupported();
        }
    }

    function _transferFeesAndFunds(address from, address to, address currency, uint256 amount) internal nonReentrant {
        uint256 finalAmount = amount;
        uint256 protocolFeeAmount = (PROTOCOL_FEE * amount) / 10000;
        if ((PROTOCOL_FEE_RECIEVER != address(0)) && (protocolFeeAmount != 0)) {
            finalAmount -= protocolFeeAmount;
            IERC20(currency).transferFrom(from, PROTOCOL_FEE_RECIEVER, protocolFeeAmount);
        }
        IERC20(currency).transferFrom(from, to, finalAmount);
    }

    // VIEWS

    function getIsUserOrderNonceExecutedOrCanceled(address add, uint256 nonce) public view returns (bool) {
        return isUserOrderNonceExecutedOrCancelled[add][nonce];
    }

    function getCurrentMinNonceForAddress(address add) public view returns (uint256) {
        return userMinOrderNonce[add];
    }

    function getDomainSeparator() public view returns (bytes32) {
        return DOMAIN_SEPARATOR;
    }

    // ADMIN

    function setProtocolFeeReciever(address protocolFeeReciever) external onlyOwner {
        // no need to make these cutom, admins will be calling these
        require(protocolFeeReciever != address(0), "Invalid address");
        PROTOCOL_FEE_RECIEVER = protocolFeeReciever;
    }

    function setProtocolFee(uint256 protocolFee) external onlyOwner {
        // no need to make these custom, admins will be calling these
        require(protocolFee < 10000, "Fee cannot be more than 100%");
        PROTOCOL_FEE = protocolFee;
    }
}

/*
 * 88888888ba  88      a8P  88
 * 88      "8b 88    ,88'   88
 * 88      ,8P 88  ,88"     88
 * 88aaaaaa8P' 88,d88'      88
 * 88""""88'   8888"88,     88
 * 88    `8b   88P   Y8b    88
 * 88     `8b  88     "88,  88
 * 88      `8b 88       Y8b 88888888888
 *
 * Marketplace: Marketplace.sol
 *
 * MIT License
 * ===========
 *
 * Copyright (c) 2022 Rumble League Studios Inc.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 */
