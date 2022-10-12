// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "../Order.sol";

// TODO: add docs for each function here
// see, for example: https://github.com/hifi-finance/hifi/tree/main/packages/protocol/contracts/core
interface IMarketplace {
    function fulfillOrder(Orders.Order calldata order) external;

    function getCurrentNonceForAddress(address add) external returns (uint256);

    function incrementCurrentNonceForAddress(address add) external;

    function cancelMultipleOrders(uint256[] calldata orderNonces) external;

    function cancelAllOrdersForSender(uint256 minNonce) external;
}