// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

library Orders {
    
    bytes32 internal constant ORDER_TYPEHASH = keccak256(
      "Order(bool isAsk,address signer,bytes signature,uint256 nonce,uint256 startTime,uint256 endTime,address collection,uint256 tokenId,uint256 amount,uint256 price,address currency,bytes params)"
    );
    bytes32 internal constant EIP712DOMAIN_TYPEHASH = keccak256(
        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
    );

    struct Order {
        bool isAsk; // false if create an offer
        address signer; // user wallet address
        bytes signature; // signature to verify
        uint256 nonce; // used for cancelling orders, should be unique
        uint256 startTime; // timestamp after which order is active
        uint256 endTime; // timestamp after which order is no longer active
        address collection; // asset collection contract address
        uint256 tokenId; // asset token id
        uint256 amount; // amount of asstes
        uint256 price; // the ask/bid price
        address currency; // ERC20 token contract address
        bytes params; // random params that can be used for different purposes
    }

    function hash(Orders.Order memory order)
        internal
        pure
        returns (bytes32)
    {
        return
            keccak256(
                abi.encode(
                    ORDER_TYPEHASH,
                    order.isAsk,
                    order.signer,
                    order.nonce,
                    order.startTime,
                    order.endTime,
                    order.collection,
                    order.tokenId,
                    order.amount,
                    order.price,
                    order.currency,
                    keccak256(order.params)
                )
            );
    }
}
