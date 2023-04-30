// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "forge-std/Test.sol";
import "../DamnValuableToken.sol";
import "solmate/src/tokens/WETH.sol";

import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
// import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

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

  uint256 internal constant PLAYER_INITIAL_TOKEN_BALANCE = 10000e18;
  uint256 internal constant PLAYER_INITIAL_ETH_BALANCE = 20e18;

  uint256 internal constant POOL_INITIAL_TOKEN_BALANCE = 1000000e18;

  DamnValuableToken internal token;
  WETH internal weth;
  IUniswapV2Factory internal uniswapFactory;
  // IUniswapV2Router01 internal uniswapRouter;

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
        abi.encode(0x0000000000000000000000000000000000000000)
      )
    );
    /*
    uniswapRouter = IUniswapV2Router01(
      deployCode(
        "uniswapV2Router02.sol",
        abi.encode(
          address(uniswapFactory),
          address(weth)
        )
      )
    );
    */

    // Create Uniswap pair against WETH and add liquidity
    // token.approve(address(uniswapRouter), UNISWAP_INITIAL_TOKEN_RESERVE);
    /*
    uniswapRouter.addLiquidityETH
      { value : UNISWAP_INITIAL_WETH_RESERVE }(
      address(token),
      UNISWAP_INITIAL_TOKEN_RESERVE,    // amountTokenDesired
      0,                                // amountTokenMin
      0,                                // amountETHMin
      deployer,                         // to
      (block.number + 1000) * 2         // deadline
    );
    */

    vm.stopPrank();
/*





  await uniswapRouter.addLiquidityETH(
      token.address,
      UNISWAP_INITIAL_TOKEN_RESERVE,                              // amountTokenDesired
      0,                                                          // amountTokenMin
      0,                                                          // amountETHMin
      deployer.address,                                           // to
      (await ethers.provider.getBlock('latest')).timestamp * 2,   // deadline
      { value: UNISWAP_INITIAL_WETH_RESERVE }
  );




  uniswapExchange = await UniswapPairFactory.attach(
      await uniswapFactory.getPair(token.address, weth.address)
  );
  expect(await uniswapExchange.balanceOf(deployer.address)).to.be.gt(0);

  // Deploy the lending pool
  lendingPool = await (await ethers.getContractFactory('PuppetV2Pool', deployer)).deploy(
      weth.address,
      token.address,
      uniswapExchange.address,
      uniswapFactory.address
  );

  // Setup initial token balances of pool and player accounts
  await token.transfer(player.address, PLAYER_INITIAL_TOKEN_BALANCE);
  await token.transfer(lendingPool.address, POOL_INITIAL_TOKEN_BALANCE);

  // Check pool's been correctly setup
  expect(
      await lendingPool.calculateDepositOfWETHRequired(10n ** 18n)
  ).to.eq(3n * 10n ** 17n);
  expect(
      await lendingPool.calculateDepositOfWETHRequired(POOL_INITIAL_TOKEN_BALANCE)
  ).to.eq(300000n * 10n ** 18n);
*/
  }

  function validate() external {
    // ???
/*
// Player has taken all tokens from the pool
expect(
    await token.balanceOf(lendingPool.address)
).to.be.eq(0);

expect(
    await token.balanceOf(player.address)
).to.be.gte(POOL_INITIAL_TOKEN_BALANCE);
});
*/
  }
}
