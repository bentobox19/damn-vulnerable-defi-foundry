// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "forge-std/Test.sol";

import "./SelfiePool.sol";

contract SelfieLevel is StdAssertions {
  Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));
  address payable private constant deployer = payable(address(uint160(uint256(keccak256(abi.encodePacked("deployer"))))));

  uint256 internal constant TOKEN_INITIAL_SUPPLY = 2_000_000e18;
  uint256 internal constant TOKENS_IN_POOL = 1_500_000e18;

  DamnValuableTokenSnapshot token;
  SimpleGovernance governance;
  SelfiePool pool;

  function setup() external {
    vm.startPrank(deployer);

    token = new DamnValuableTokenSnapshot(TOKEN_INITIAL_SUPPLY);

    governance = new SimpleGovernance(address(token));
    assertEq(governance.getActionCounter(), 1);

    pool = new SelfiePool(address(token), address(governance));
    assertEq(address(pool.token()), address(token));
    assertEq(address(pool.governance()), address(governance));

    token.transfer(address(pool), TOKENS_IN_POOL);
    token.snapshot();
    assertEq(token.balanceOf(address(pool)), TOKENS_IN_POOL);
    assertEq(pool.maxFlashLoan(address(token)), TOKENS_IN_POOL);
    assertEq(pool.flashFee(address(token), 0), 0);

    vm.stopPrank();
  }

  function validate() external {
    assertEq(token.balanceOf(msg.sender), TOKENS_IN_POOL);
    assertEq(token.balanceOf(address(pool)), 0);
  }
}
