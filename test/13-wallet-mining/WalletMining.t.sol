// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {WalletMiningLevel} from "../../src/wallet-mining/WalletMiningLevel.sol";

import "forge-std/Test.sol";

contract WalletMiningTest is Test {
  WalletMiningLevel level = new WalletMiningLevel();

  function setUp() public {
    level.setup();
  }

  function testExploit() public {
    // level.validate()
  }
}
