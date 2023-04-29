// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "forge-std/Test.sol";
import "./PuppetV2Pool.sol";

contract PuppetLevel is StdAssertions {
  Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));
  address payable private constant deployer = payable(address(uint160(uint256(keccak256(abi.encodePacked("deployer"))))));

  // uint256 internal constant UNISWAP_INITIAL_TOKEN_RESERVE = 10e18;

  // DamnValuableToken public token;
  // IUniswapFactory internal uniswapFactory;
  // IUniswapExchange public uniswapExchange;
  // PuppetPool public lendingPool;

  function setup() external {
    vm.startPrank(deployer);

    // ???

    vm.stopPrank();
  }

  function validate() external {
    // ???
  }
}
