// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "forge-std/Test.sol";

import "./NaiveReceiverLenderPool.sol";
import "./FlashLoanReceiver.sol";

contract NaiveReceiverLevel is StdAssertions {
  Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));
  address payable private constant deployer = payable(address(uint160(uint256(keccak256(abi.encodePacked("deployer"))))));

  uint256 internal constant ETHER_IN_POOL = 1_000e18;
  uint256 internal constant ETHER_IN_RECEIVER = 10e18;

  NaiveReceiverLenderPool public pool;
  FlashLoanReceiver public receiver;

  function setup() external {
    vm.startPrank(deployer);
    vm.deal(deployer, ETHER_IN_POOL + ETHER_IN_RECEIVER);

    pool = new NaiveReceiverLenderPool();
    (bool result,) = address(pool).call{value: ETHER_IN_POOL}("");
    assertEq(result, true);
    address ETH = pool.ETH();
    assertEq(address(pool).balance, ETHER_IN_POOL);
    assertEq(pool.maxFlashLoan(ETH), ETHER_IN_POOL);
    assertEq(pool.flashFee(ETH, 0), 1e18);

    receiver = new FlashLoanReceiver(address(pool));
    (result,) = address(receiver).call{value: ETHER_IN_RECEIVER}("");
    assertEq(result, true);
    vm.expectRevert();
    receiver.onFlashLoan(deployer, ETH, ETHER_IN_RECEIVER, 1e18, "0x");
    assertEq(address(receiver).balance, ETHER_IN_RECEIVER);

    vm.stopPrank();
  }

  function validate() external {
    // All ETH has been drained from the receiver
    assertEq(address(receiver).balance, 0);
    assertEq(address(pool).balance, ETHER_IN_POOL + ETHER_IN_RECEIVER);
  }
}
