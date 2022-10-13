// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;


interface IMarketplaceErrors {
    error InvalidNonce();
    error OrderExpired();
    error OrderNotActive();
    error InterfaceNotSupported();
    error InvalidSigner();
    error InvalidChain();
    error InvalidCurrencyInterface();
}