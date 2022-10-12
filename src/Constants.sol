// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

bytes32 constant NAME_HASH = keccak256(bytes("RKL Marketplace"));
bytes32 constant VERSION_HASH = keccak256(bytes("1"));
bytes32 constant EIP712_DOMAIN_TYPEHASH = keccak256(
    abi.encodePacked(
        "EIP712Domain(", "string name,", "string version,", "uint256 chainId,", "address verifyingContract", ")"
    )
);