// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";

import "./TrusterLenderPool.sol";
import "../DamnValuableToken.sol";

contract TrusterLevel is StdAssertions {
  Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));
  address payable private constant deployer = payable(address(uint160(uint256(keccak256(abi.encodePacked("deployer"))))));

  uint256 public constant TOKENS_IN_POOL = 1_000_000e18;

  DamnValuableToken public token;
  TrusterLenderPool public pool;

  function setup() external {
    vm.startPrank(deployer);

    token = new DamnValuableToken();
    pool = new TrusterLenderPool(token);
    assertEq(address(pool.token()), address(token));

    token.transfer(address(pool), TOKENS_IN_POOL);
    assertEq(token.balanceOf(address(pool)), TOKENS_IN_POOL);

    vm.stopPrank();

    // checking that we don't have any tokens
    assertEq(token.balanceOf(msg.sender), 0);
  }

  function validate() external {
    // did we drain the pool?
    assertEq(token.balanceOf(msg.sender), TOKENS_IN_POOL);
    assertEq(token.balanceOf(address(pool)), 0);
  }
}
