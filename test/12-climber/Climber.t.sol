// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {ClimberLevel} from "../../src/climber/ClimberLevel.sol";

import "forge-std/Test.sol";

contract ClimberTest is Test {
  ClimberLevel level = new ClimberLevel();

  function setUp() public {
    level.setup();
  }

  function test() public {
    // level.validate();
  }
}
