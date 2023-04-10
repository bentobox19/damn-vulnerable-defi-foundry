// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "forge-std/Test.sol";
import "./PuppetPool.sol";
import "./UniswapV1Exchange.sol";
import "./UniswapV1Factory.sol";

interface IUniswapFactory {
  function initializeFactory(address) external;
  function createExchange(address) external;
}

interface IUniswapExchange {
  function addLiquidity(uint256, uint256, uint256) external payable;
  function getTokenToEthInputPrice(uint256) external returns(uint256);
  function tokenToEthSwapInput(uint256, uint256, uint256) external;
}

contract PuppetLevel is StdAssertions {
  Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));
  address payable private constant deployer = payable(address(uint160(uint256(keccak256(abi.encodePacked("deployer"))))));

  uint256 internal constant UNISWAP_INITIAL_TOKEN_RESERVE = 10e18;
  uint256 internal constant UNISWAP_INITIAL_ETH_RESERVE = 10e18;
  uint256 internal constant PLAYER_INITIAL_TOKEN_BALANCE = 1_000e18;
  uint256 internal constant PLAYER_INITIAL_ETH_BALANCE = 25e18;
  uint256 internal constant POOL_INITIAL_TOKEN_BALANCE = 100_000e18;

  DamnValuableToken public token;
  IUniswapFactory internal uniswapFactory;
  IUniswapExchange public uniswapExchange;
  PuppetPool public lendingPool;

  function setup() external {
    vm.startPrank(deployer);
    vm.deal(deployer, UNISWAP_INITIAL_ETH_RESERVE);

    vm.deal(msg.sender, PLAYER_INITIAL_ETH_BALANCE);
    assertEq(msg.sender.balance, PLAYER_INITIAL_ETH_BALANCE);

    token = new DamnValuableToken();

    // deploy a exchange that will be used as the factory template
    address exchangeTemplateAddress = new UniswapV1Exchange().exchangeTemplateAddress();

    // deploy factory, initializing it with the address of the template exchange
    address uniswapFactoryAddress = new UniswapV1Factory().uniswapFactoryAddress();
    uniswapFactory = IUniswapFactory(uniswapFactoryAddress);
    uniswapFactory.initializeFactory(exchangeTemplateAddress);

    // create a new exchange for the token, and retrieve the deployed exchange's address
    vm.recordLogs();
    uniswapFactory.createExchange(address(token));
    Vm.Log[] memory entries = vm.getRecordedLogs();
    address uniswapExchangeAddress = address(uint160(uint256(entries[0].topics[2])));
    uniswapExchange = IUniswapExchange(uniswapExchangeAddress);

    // deploy the lending pool
    lendingPool = new PuppetPool(address(token), uniswapExchangeAddress);

    // add initial token and ETH liquidity to the pool
    token.approve(uniswapExchangeAddress, UNISWAP_INITIAL_TOKEN_RESERVE);
    uniswapExchange.addLiquidity
      {value: UNISWAP_INITIAL_ETH_RESERVE}
    (
      0,                              // min_liquidity
      UNISWAP_INITIAL_TOKEN_RESERVE,
      block.timestamp * 2             // deadline
    );

    // ensure Uniswap exchange is working as expected
    uint256 tokenToEthInputPrice =
      (1e18 * 997 * UNISWAP_INITIAL_ETH_RESERVE) /
      (UNISWAP_INITIAL_TOKEN_RESERVE * 1000 + 1e18 * 997);
    assertEq(uniswapExchange.getTokenToEthInputPrice(1e18), tokenToEthInputPrice);

    // setup initial token balances of pool and player accounts
    token.transfer(msg.sender, PLAYER_INITIAL_TOKEN_BALANCE);
    token.transfer(address(lendingPool), POOL_INITIAL_TOKEN_BALANCE);

    // ensure correct setup of pool. For example, to borrow 1 need to deposit 2
    assertEq(lendingPool.calculateDepositRequired(1e18), 2e18);
    assertEq(
      lendingPool.calculateDepositRequired(POOL_INITIAL_TOKEN_BALANCE),
      POOL_INITIAL_TOKEN_BALANCE * 2
    );

    vm.stopPrank();
  }

  function validate() external {
    // In the challenge written in hardhat we checked that the
    // attacker did everything in one single transaction.
    // we omit this check in forge.

    // player has taken all tokens from the pool
    assertEq(token.balanceOf(address(lendingPool)), 0);
    assertEq(token.balanceOf(msg.sender), POOL_INITIAL_TOKEN_BALANCE);
  }
}
