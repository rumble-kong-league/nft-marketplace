// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IERC1271} from "@openzeppelin/contracts/interfaces/IERC1271.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract TestERC1271 is IERC1271, IERC721Receiver {
    bytes4 internal constant MAGICVALUE = 0x1626ba7e;

    function isValidSignature(bytes32, bytes calldata)
        public
        pure
        override
        returns (bytes4 magicValue)
    {
        return MAGICVALUE;
    }

    function onERC721Received(address, address, uint256, bytes calldata)
        external
        pure
        returns (bytes4)
    {
        return this.onERC721Received.selector;
    }
}
