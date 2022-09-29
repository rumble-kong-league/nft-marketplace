//SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IMarketplace {

    function getCurrentNonceForAddress(address add) external returns (uint256);

    function incrementCurrentNonceForAddress(address add) external;

}