//SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./interfaces/IMarketplace.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

import {SignatureVerifier} from "./SignatureVerifier.sol";
import {
    _EIP_712_DOMAIN_TYPEHASH,
    _NAME_HASH,
    _VERSION_HASH
} from "./Constants.sol";

contract Marketplace is IMarketplace, Ownable, SignatureVerifier {
    using Orders for Orders.Order;

    mapping(address => uint256) public userCurrentOrderNonce; // used to keep track of a user's latest nonce

    event OrderExecuted(address from, address to, address collection, uint256 tokenId, address currency, uint256 price);

    constructor() {}

    // ============ ORDER METHODS ==================

    function fulfillOrder(Orders.Order calldata order) external {

        _validateOrder(order);

        // TODO: Cancel nonce

        address from = order.isAsk ? order.signer : msg.sender;
        address to = order.isAsk ? msg.sender : order.signer;
        _fulfillOrder( order, from, to );
    }

    function _validateOrder(Orders.Order calldata order) internal view {

        bytes32 _DOMAIN_SEPARATOR = _deriveDomainSeparator();

        // Validate signature
        bytes32 digest = _deriveEIP712Digest(_DOMAIN_SEPARATOR, order.hash());
        _assertValidSignature(
            order.signer,
            digest,
            order.signature
        );
    }

    function _deriveDomainSeparator() public view returns (bytes32) {
        return keccak256(
            abi.encode(
                _EIP_712_DOMAIN_TYPEHASH,
                _NAME_HASH,
                _VERSION_HASH,
                block.chainid,
                address(this)
            )
        );
    }

    function _fulfillOrder(Orders.Order calldata order, address from, address to) internal {
            // Transfer ERC20 tokens
            _transferFeesAndFunds(
                msg.sender,
                order.signer,
                order.currency,
                order.price
            );

            // Transfer ERC721 tokens
            _transferNonFungibleToken(
                order.collection,
                order.signer,
                msg.sender,
                order.tokenId,
                order.amount
            );

            emit OrderExecuted(from, to, order.collection, order.tokenId, order.currency, order.price);
    }



    // ============ Transfer methods ==============

    /**
     * @notice Transfer NFT
     * @param collection address of the token collection
     * @param from address of the sender
     * @param to address of the recipient
     * @param tokenId tokenId
     * @param amount amount of tokens (1 for ERC721, 1+ for ERC1155)
     * @dev For ERC721, amount is not used
     */
    function _transferNonFungibleToken(
        address collection,
        address from,
        address to,
        uint256 tokenId,
        uint256 amount
    ) internal {
        // TODO: this does not handle ERC1155
        // https://docs.openzeppelin.com/contracts/2.x/api/token/erc721#IERC721-safeTransferFrom
        // TODO: check your link above. 2.x is the oldest openzeppelin contracts. Current version is 4.x
        IERC721(collection).safeTransferFrom(from, to, tokenId);
    }

    /**
     * @notice Transfer fees and funds to royalty recipient, protocol, and seller
     * @param from sender of the funds
     * @param to seller's recipient
     * @param amount amount being transferred (in currency)
     */
    function _transferFeesAndFunds(
        address from,
        address to,
        address currency,
        uint256 amount
    ) internal {

        // 1. Protocol fee?
        // 2. Royalty fee?
        // 3. Transfer final amount (post-fees) to seller
        {
            IERC20(currency).transferFrom(from, to, amount);
        }
    }

    // ============ NONCE METHODS ==================

    function getCurrentNonceForAddress(address add)
        public
        view
        returns (uint256)
    {
        return userCurrentOrderNonce[add];
    }

    function incrementCurrentNonceForAddress(address add) public onlyOwner {
        userCurrentOrderNonce[add]++;
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
