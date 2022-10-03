//SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "../Order.sol";

interface IMarketplace {

    function fulfillOrder(Orders.Order calldata order) external;

    function getCurrentNonceForAddress(address add) external returns (uint256);

    function incrementCurrentNonceForAddress(address add) external;

}