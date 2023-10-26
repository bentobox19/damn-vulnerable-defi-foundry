// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ClimberTimelock} from "./ClimberTimelock.sol";
import {ClimberVault} from "./ClimberVault.sol";
import {DamnValuableToken} from "dvt/DamnValuableToken.sol";

import "forge-std/Test.sol";

contract ClimberLevel is StdAssertions, StdCheats {
  Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));
  address payable private constant deployerAddress = payable(address(uint160(uint256(keccak256(abi.encodePacked("deployer"))))));
  address payable private constant playerAddress = payable(address(uint160(uint256(keccak256(abi.encodePacked("player"))))));
  address payable private constant proposerAddress = payable(address(uint160(uint256(keccak256(abi.encodePacked("proposer"))))));
  address payable private constant sweeperAddress = payable(address(uint160(uint256(keccak256(abi.encodePacked("sweeper"))))));

  ClimberVault private vault;
  ClimberTimelock private timelock;
  DamnValuableToken public token;

  uint256 private constant PLAYER_INITIAL_ETH_BALANCE = 1e17;
  uint256 private constant TIMELOCK_DELAY = 60 * 60;
  uint256 private constant VAULT_TOKEN_BALANCE = 10_000_000e18;

  function setup() external {
    vm.startPrank(deployerAddress);

    vm.deal(playerAddress, PLAYER_INITIAL_ETH_BALANCE);
    assertEq(playerAddress.balance, PLAYER_INITIAL_ETH_BALANCE);

    // Deploy the vault behind a proxy using the UUPS pattern,
    // passing the necessary addresses for the `ClimberVault::initialize(address,address,address)` function
    //     vault = new ClimberVault(deployerAddress, proposerAddress, sweeperAddress);
    {
    ClimberVault implementation = new ClimberVault();
    bytes memory data = abi.encodeWithSignature(
      "initialize(address,address,address)",
      deployerAddress,
      proposerAddress,
      sweeperAddress
    );
    ERC1967Proxy proxy = new ERC1967Proxy(
      address(implementation),
      data
    );
    vault = ClimberVault(address(proxy));
    }

    assertEq(vault.getSweeper(), sweeperAddress);
    assertGt(vault.getLastWithdrawalTimestamp(), 0);
    assertNotEq(vault.owner(), address(0));
    assertNotEq(vault.owner(), deployerAddress);

    // Instantiate timelock
    timelock = ClimberTimelock(payable(vault.owner()));

    // Ensure timelock delay is correct and cannot be changed
    assertEq(timelock.delay(), TIMELOCK_DELAY);
    vm.expectRevert(bytes4(keccak256(bytes("CallerNotTimelock()"))));
    timelock.updateDelay(uint64(TIMELOCK_DELAY + 1));

    // Ensure timelock roles are correctly initialized
    assertTrue(timelock.hasRole(keccak256("PROPOSER_ROLE"), proposerAddress));
    assertTrue(timelock.hasRole(keccak256("ADMIN_ROLE"), deployerAddress));
    assertTrue(timelock.hasRole(keccak256("ADMIN_ROLE"), address(timelock)));

    // Deploy token and transfer initial token balance to the vault
    token = new DamnValuableToken();
    token.transfer(address(vault), VAULT_TOKEN_BALANCE);

    vm.stopPrank();
  }

  function validate() external {
    assertEq(token.balanceOf(address(vault)), 0);
    assertEq(token.balanceOf(playerAddress), VAULT_TOKEN_BALANCE);
  }
}
