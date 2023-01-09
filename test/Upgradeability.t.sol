// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin-upgradeable/contracts/proxy/ClonesUpgradeable.sol";

import "forge-std/Test.sol";
import "../src/Marketplace.sol";
import "../src/MarketplaceProxy.sol";

/**
    * @dev This contract inherits the Forge's built-in Test contract.
    * @notice ERC1967 minimal proxy is just used to demonstrate the condition
    *         bypassing in the UUPS contract
    */
contract UpgradeabilityTest is Test {
    using ClonesUpgradeable for address;

    Marketplace public impl;
    MarketplaceProxy public proxy;
    ProxyAdmin private proxyAdmin;

    address private owner;
    address private nonAuthorized;
    bytes public data;

    bytes32 internal constant IMPL_SLOT = bytes32(uint256(keccak256('eip1967.proxy.implementation')) - 1);

    function setUp() external {
        owner = vm.addr(1);
        nonAuthorized = address(20);

        vm.startPrank(owner);
        // Deploy the implementation contract        
        impl = new Marketplace();

        // Deploy the proxy admin contract
        proxyAdmin = new ProxyAdmin();
        
        // Deploy the proxy contract
        data = abi.encodeWithSignature("initialize()");
        proxy = new MarketplaceProxy(address(impl), address(proxyAdmin), data);
        vm.stopPrank();
    }

    function testInitializable() external {
        assertFalse(impl.isInitialized());

        vm.prank(owner);
        impl.initialize();

        assertTrue(impl.isInitialized());
    }
    
    function testProxyImplSlot() external {
        bytes32 proxySlot = vm.load(address(proxy), IMPL_SLOT);

        assertEq(proxySlot, bytes32(uint256(uint160(address(impl)))));
        assertEq(proxyAdmin.getProxyImplementation(proxy), address(impl));
    }

    function testUpgrade() external {
        vm.startPrank(owner);

        Marketplace newImpl = new Marketplace();

        impl.initialize();
        assertTrue(impl.isInitialized());

        // Checking the IMPL_SLOT before upgrading the implementation contract
        bytes32 proxySlotBefore = vm.load(address(proxy), IMPL_SLOT);
        assertEq(proxySlotBefore, bytes32(uint256(uint160(address(impl)))));
        assertEq(proxyAdmin.getProxyImplementation(proxy), address(impl));

        proxyAdmin.upgrade(proxy, address(newImpl));

        bytes32 proxySlotAfter = vm.load(address(proxy), IMPL_SLOT);
        assertEq(proxySlotAfter, bytes32(uint256(uint160(address(newImpl)))));
        assertEq(proxyAdmin.getProxyImplementation(proxy), address(newImpl));

        // Upgrade is successful!
        vm.stopPrank();
    }

    function testUnauthorizedUpgradeAttempt() external {
        // Attempt to upgrade the implementation contract by a non-authorized person
        vm.startPrank(nonAuthorized);

        Marketplace unauthorizedNewImpl= new Marketplace();        

        // upgradeTo() is not successful        
        vm.expectRevert("Ownable: caller is not the owner");
        proxyAdmin.upgrade(proxy,address(unauthorizedNewImpl));
        
        vm.stopPrank();
        
        assertEq(vm.load(address(proxy), IMPL_SLOT), bytes32(uint256(uint160(address(impl)))));
    }
}