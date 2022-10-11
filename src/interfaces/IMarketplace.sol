// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "../Order.sol";

interface IMarketplace {
    function fulfillOrder(Orders.Order calldata order) external;

    function getCurrentNonceForAddress(address add) external returns (uint256);

    function incrementCurrentNonceForAddress(address add) external;

    function cancelMultipleOrders(uint256[] calldata orderNonces) external;

    function cancelAllOrdersForSender(uint256 minNonce) external;
}
