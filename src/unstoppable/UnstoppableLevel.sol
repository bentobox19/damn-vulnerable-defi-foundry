// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "forge-std/Test.sol";
// import "forge-std/Vm.sol";

import "./UnstoppableVault.sol";
import "./ReceiverUnstoppable.sol";
import "../DamnValuableToken.sol";

contract UnstoppableLevel is StdAssertions {
  uint256 internal constant TOKENS_IN_VAULT = 1_000_000e18;
  uint256 internal constant INITIAL_ATTACKER_TOKEN_BALANCE = 100e18;

  DamnValuableToken internal token;
  UnstoppableVault internal vault;

  function setup() external {
    token = new DamnValuableToken();
    vault = new UnstoppableVault(token, msg.sender, msg.sender);
    assertEq(address(vault.asset()), address(token));

    token.approve(address(vault), TOKENS_IN_VAULT);
    vault.deposit(TOKENS_IN_VAULT, msg.sender);
    assertEq(token.balanceOf(address(vault)), TOKENS_IN_VAULT);
    assertEq(vault.totalAssets(), TOKENS_IN_VAULT);
    assertEq(vault.totalSupply(), TOKENS_IN_VAULT);
    assertEq(vault.maxFlashLoan(address(token)), TOKENS_IN_VAULT);
    assertEq(vault.flashFee(address(token), TOKENS_IN_VAULT - 1), 0);
    assertEq(vault.flashFee(address(token), TOKENS_IN_VAULT), 50_000e18);


    /*

    // we have to create a player, different from the deployer

    await token.transfer(player.address, INITIAL_PLAYER_TOKEN_BALANCE);
    expect(await token.balanceOf(player.address)).to.eq(INITIAL_PLAYER_TOKEN_BALANCE);

    // Show it's possible for someUser to take out a flash loan
    receiverContract = await (await ethers.getContractFactory('ReceiverUnstoppable', someUser)).deploy(
        vault.address
    );
    await receiverContract.executeFlashLoan(100n * 10n ** 18n);

    */
  }

  function validate() external {
    // ???
  }
}
