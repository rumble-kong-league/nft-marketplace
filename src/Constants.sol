// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

bytes32 constant EIP2098_allButHighestBitMask = (0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);

uint256 constant EIP712_DomainSeparator_offset = 0x02;
uint256 constant EIP712_OrderHash_offset = 0x22;
uint256 constant EIP712_DigestPayload_size = 0x42;

uint256 constant EIP712_PREFIX = (0x1901000000000000000000000000000000000000000000000000000000000000);

bytes32 constant NAME_HASH = keccak256(bytes("RKL Marketplace"));
bytes32 constant VERSION_HASH = keccak256(bytes("1"));
bytes32 constant EIP_712_DOMAIN_TYPEHASH = keccak256(
    abi.encodePacked(
        "EIP712Domain(", "string name,", "string version,", "uint256 chainId,", "address verifyingContract", ")"
    )
);
