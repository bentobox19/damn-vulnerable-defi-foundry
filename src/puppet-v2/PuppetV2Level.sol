// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "forge-std/Test.sol";
import "../utils/DamnValuableToken.sol";
import "solmate/src/tokens/WETH.sol";

import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

interface IPuppetV2Pool {
  function borrow(uint256) external;
  function calculateDepositOfWETHRequired(uint256) external view returns (uint256);
}

contract PuppetV2Level is StdAssertions, StdCheats {
  Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));
  address payable private constant deployer = payable(address(uint160(uint256(keccak256(abi.encodePacked("deployer"))))));

  // Uniswap v2 exchange will start with 100 tokens and 10 WETH in liquidity
  uint256 internal constant UNISWAP_INITIAL_TOKEN_RESERVE = 100e18;
  uint256 internal constant UNISWAP_INITIAL_WETH_RESERVE = 10e18;

  uint256 public constant PLAYER_INITIAL_TOKEN_BALANCE = 10000e18;
  uint256 internal constant PLAYER_INITIAL_ETH_BALANCE = 20e18;

  uint256 public constant POOL_INITIAL_TOKEN_BALANCE = 1000000e18;

  DamnValuableToken public token;
  WETH public weth;
  IUniswapV2Factory internal uniswapFactory;
  IUniswapV2Router01 public uniswapRouter;
  IUniswapV2Pair internal uniswapExchange;
  IPuppetV2Pool public lendingPool;

  function setup() external {
    vm.startPrank(deployer);
    vm.deal(deployer, UNISWAP_INITIAL_WETH_RESERVE);

    vm.deal(msg.sender, PLAYER_INITIAL_ETH_BALANCE);
    assertEq(msg.sender.balance, PLAYER_INITIAL_ETH_BALANCE);

    // Deploy tokens to be traded
    token = new DamnValuableToken();
    weth = new WETH();

    // Deploy Uniswap Factory and Router
    uniswapFactory = IUniswapV2Factory(
      deployCode(
        "UniswapV2Factory.sol",
        abi.encode(0x0000000000000000000000000000000000000000)));
    uniswapRouter = IUniswapV2Router01(
      deployCode(
        "uniswapV2Router02.sol",
        abi.encode(
          address(uniswapFactory),
          address(weth)
        )));

    // Create Uniswap pair against WETH and add liquidity
    token.approve(address(uniswapRouter), UNISWAP_INITIAL_TOKEN_RESERVE);
    uniswapRouter.addLiquidityETH
      { value : UNISWAP_INITIAL_WETH_RESERVE }(
      address(token),
      UNISWAP_INITIAL_TOKEN_RESERVE,    // amountTokenDesired
      0,                                // amountTokenMin
      0,                                // amountETHMin
      deployer,                         // to
      (block.number + 1000) * 2         // deadline
    );

    uniswapExchange = IUniswapV2Pair(
      uniswapFactory.getPair(address(token), address(weth)));
    assertGt(uniswapExchange.balanceOf(deployer), 0);

    // Deploy the lending pool
    lendingPool = IPuppetV2Pool(
      deployCode(
        "PuppetV2Pool.sol",
        abi.encode(
          address(weth),
          address(token),
          address(uniswapExchange),
          address(uniswapFactory)
        )));

    // Setup initial token balances of pool and player accounts
    token.transfer(msg.sender, PLAYER_INITIAL_TOKEN_BALANCE);
    token.transfer(address(lendingPool), POOL_INITIAL_TOKEN_BALANCE);

    // Check pool's been correctly setup
    assertEq(lendingPool.calculateDepositOfWETHRequired(1e18), 3e17);
    assertEq(lendingPool.calculateDepositOfWETHRequired(
      POOL_INITIAL_TOKEN_BALANCE), 300000e18);

    vm.stopPrank();
  }

  function validate() external {
    // Player has taken all tokens from the pool
    assertEq(token.balanceOf(address(lendingPool)), 0);
    assertGe(token.balanceOf(msg.sender), POOL_INITIAL_TOKEN_BALANCE);
  }
}
