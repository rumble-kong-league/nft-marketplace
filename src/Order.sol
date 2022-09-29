// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

struct Order {
  bool isAsk;
  address signer;
  bytes signature;
  uint256 nonce;
  uint256 startTime;
  uint256 endTime;
  address collection; 
  uint256 tokenId;
  uint256 amount;
  uint256 price;
  address currency;
  bytes params;
}