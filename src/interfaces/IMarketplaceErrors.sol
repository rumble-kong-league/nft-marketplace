// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;


// TODO: add docs for each error
// see, for example: https://github.com/hifi-finance/hifi/tree/main/packages/protocol/contracts/core
interface IMarketplaceErrors {
    error InvalidNonce();
    error OrderExpired();
    error OrderNotActive();
    error InvalidTokenAmount();
    error InvalidSigner();
    error InvalidSignature();
}