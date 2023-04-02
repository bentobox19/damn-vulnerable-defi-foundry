// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";

import "./SideEntranceLenderPool.sol";

contract SideEntranceLevel is StdAssertions {
  Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));
  address payable private constant deployer = payable(address(uint160(uint256(keccak256(abi.encodePacked("deployer"))))));

  uint256 internal constant ETHER_IN_POOL = 1_000e18;
  uint256 internal constant PLAYER_INITIAL_ETH_BALANCE = 1e18;

  SideEntranceLenderPool public pool;

  function setup() external {
    vm.startPrank(deployer);
    vm.deal(deployer, ETHER_IN_POOL);

    pool = new SideEntranceLenderPool();
    pool.deposit{value: ETHER_IN_POOL}();
    assertEq(address(pool).balance, ETHER_IN_POOL);

    vm.stopPrank();

    vm.deal(msg.sender, PLAYER_INITIAL_ETH_BALANCE);
    assertEq(msg.sender.balance, PLAYER_INITIAL_ETH_BALANCE);
  }

  function validate() external {
    // did we drain the pool?
    assertEq(msg.sender.balance, PLAYER_INITIAL_ETH_BALANCE + ETHER_IN_POOL);
    assertEq(address(pool).balance, 0);
  }
}
