// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "forge-std/Test.sol";
import "../../src/selfie/SelfieLevel.sol";

contract SelfieTest is Test {
  SelfieLevel level = new SelfieLevel();

  function setUp() public {
    level.setup();
  }

  function testExploit() public {
    level.validate();
  }
}
