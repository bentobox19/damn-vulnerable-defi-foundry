// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "forge-std/Test.sol";
import "../../src/selfie/SelfieLevel.sol";

interface ISelfiePool is IERC3156FlashLender {
  function emergencyExit(address) external;
}

contract Attacker is IERC3156FlashBorrower {
  SelfieLevel level;
  ISelfiePool pool;
  IERC20 token;
  DamnValuableTokenSnapshot governance;

  constructor(SelfieLevel _level) {
    level = _level;
    pool = ISelfiePool(address(level.pool()));
    token = IERC20(address(level.token()));
    governance = DamnValuableTokenSnapshot(address(level.governance()));
  }

  function attack() public {
    pool.flashLoan(
      IERC3156FlashBorrower(this),
      address(token),
      pool.maxFlashLoan(address(token)),
      "0x"
    );
  }

  function onFlashLoan(
        address,
        address,
        uint256 amount,
        uint256,
        bytes calldata
    ) external returns (bytes32) {

    // return the loan
    token.approve(msg.sender, amount);
    return keccak256("ERC3156FlashBorrower.onFlashLoan");
  }
}

contract SelfieTest is Test {
  SelfieLevel level = new SelfieLevel();

  function setUp() public {
    level.setup();
  }

  function testExploit() public {
    // advance time 2 days
    vm.warp(block.timestamp + 2 days);

    Attacker attacker = new Attacker(level);
    attacker.attack();

    // level.validate();
  }
}
