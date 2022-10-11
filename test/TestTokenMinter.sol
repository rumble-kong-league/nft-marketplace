// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import {TestERC20} from "../test/TestERC20.sol";
import {TestERC721} from "../test/TestERC721.sol";
import {TestERC1155} from "../test/TestERC1155.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract TestTokenMinter is Test {
    uint256 constant MAX_INT = ~uint256(0);

    uint256 internal alicePk = 0xa11ce;
    uint256 internal bobPk = 0xb0b;
    uint256 internal calPk = 0xca1;
    address payable internal alice = payable(vm.addr(alicePk));
    address payable internal bob = payable(vm.addr(bobPk));
    address payable internal cal = payable(vm.addr(calPk));

    TestERC20 internal token1;
    TestERC20 internal token2;
    TestERC20 internal token3;

    TestERC721 internal test721_1;
    TestERC721 internal test721_2;
    TestERC721 internal test721_3;

    TestERC1155 internal test1155_1;
    TestERC1155 internal test1155_2;
    TestERC1155 internal test1155_3;

    TestERC20[] erc20s;
    TestERC721[] erc721s;
    TestERC1155[] erc1155s;

    function setUp() public virtual {
        vm.label(alice, "alice");
        vm.label(bob, "bob");
        vm.label(cal, "cal");

        _deployTestTokenContracts();
        erc20s = [token1, token2, token3];
        erc721s = [test721_1, test721_2, test721_3];
        erc1155s = [test1155_1, test1155_2, test1155_3];

        // allocate funds and tokens to test addresses

        allocateTokensAndApprovals(alice, address(this), 100);
        allocateTokensAndApprovals(bob, address(this), 100);
        allocateTokensAndApprovals(cal, address(this), 100);
    }

    function mintErc721TokenTo(address to, uint256 id) internal {
        mintErc721TokenTo(to, test721_1, id);
    }

    function mintErc721TokenTo(address to, TestERC721 token, uint256 id) internal {
        token.mint(to, id);
    }

    function mintErc20TokensTo(address to, uint256 amount) internal {
        mintErc20TokensTo(to, token1, amount);
    }

    function mintErc20TokensTo(address to, TestERC20 token, uint256 amount) internal {
        token.mint(to, amount);
    }

    function mintErc1155TokensTo(address to, uint256 id, uint256 amount) internal {
        mintErc1155TokensTo(to, test1155_1, id, amount);
    }

    function mintErc1155TokensTo(address to, TestERC1155 token, uint256 id, uint256 amount) internal {
        token.mint(to, id, amount);
    }

    /**
     * @dev deploy test token contracts
     */
    function _deployTestTokenContracts() internal {
        token1 = new TestERC20();
        token2 = new TestERC20();
        token3 = new TestERC20();
        test721_1 = new TestERC721();
        test721_2 = new TestERC721();
        test721_3 = new TestERC721();
        test1155_1 = new TestERC1155();
        test1155_2 = new TestERC1155();
        test1155_3 = new TestERC1155();

        vm.label(address(token1), "token1");
        vm.label(address(test721_1), "test721_1");
        vm.label(address(test1155_1), "test1155_1");

        emit log("Deployed test token contracts");
    }

    /**
     * @dev allocate amount of each token, 1 of each 721, and 1, 5, and 10 of respective 1155s
     */
    function allocateTokensAndApprovals(address _to, address _toApprove, uint128 _amount) internal {
        vm.deal(_to, _amount);
        for (uint256 i = 0; i < erc20s.length; ++i) {
            erc20s[i].mint(_to, _amount);
        }
        emit log_named_address("Allocated tokens to", _to);
        _setApprovals(_to, _toApprove);
    }

    function _setApprovals(address _owner, address toApprove) internal virtual {
        vm.startPrank(_owner);
        for (uint256 i = 0; i < erc20s.length; ++i) {
            erc20s[i].approve(address(toApprove), MAX_INT);
        }
        for (uint256 i = 0; i < erc721s.length; ++i) {
            erc721s[i].setApprovalForAll(address(toApprove), true);
        }
        vm.stopPrank();
        emit log_named_address("Owner proxy approved for all tokens from", _owner);
        emit log_named_address("Consideration approved for all tokens from", _owner);
    }
}
