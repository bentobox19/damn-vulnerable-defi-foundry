// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "forge-std/Test.sol";
import "solmate/src/tokens/WETH.sol";

import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";

interface IWETH {
    function balanceOf(address) external returns (uint256);
    function deposit() external payable;
    // function transfer(address to, uint value) external returns (bool);
    // function withdraw(uint) external;
}

// I don't think I'll use this code elsewhere
library StringExtensions {
  function toUint256(string memory s) internal pure returns (uint256) {
    bytes memory b = bytes(s);
    uint256 result = 0;
    require(b.length > 0, "Empty string");
    for (uint i = 0; i < b.length; i++) {
      uint8 charCode = uint8(b[i]);
      require(charCode >= 48 && charCode <= 57, "Non-numeric character detected");
      result = result * 10 + (charCode - 48);
    }
    return result;
  }
}

contract PuppetV3Level is StdAssertions, StdCheats {
  using StringExtensions for string;

  Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

  address public constant deployerAddress = payable(address(uint160(uint256(keccak256(abi.encodePacked("deployer"))))));
  address public constant playerAddress = payable(address(uint160(uint256(keccak256(abi.encodePacked("player"))))));


  uint256 internal constant UNISWAP_INITIAL_TOKEN_LIQUIDITY = 100e18;
  uint256 internal constant UNISWAP_INITIAL_WETH_LIQUIDITY = 100e18;

  uint256 internal constant PLAYER_INITIAL_TOKEN_BALANCE = 110e18;
  uint256 internal constant PLAYER_INITIAL_ETH_BALANCE = 1e18;
  uint256 internal constant DEPLOYER_INITIAL_ETH_BALANCE = 200e18;

  uint256 internal constant LENDING_POOL_INITIAL_TOKEN_BALANCE = 1_000_000e18;

  constructor() {
    string memory RPC_URL = vm.envString("RPC_URL");
    uint256 BLOCK_NUMBER = vm.envString("BLOCK_NUMBER").toUint256();
    vm.createSelectFork(RPC_URL, BLOCK_NUMBER);
  }

  function setup() public {
    vm.startPrank(deployerAddress);

    // Initialize player account
    vm.deal(playerAddress, PLAYER_INITIAL_ETH_BALANCE);
    assertEq(playerAddress.balance, PLAYER_INITIAL_ETH_BALANCE);

    // Initialize deployer account
    vm.deal(deployerAddress, DEPLOYER_INITIAL_ETH_BALANCE);
    assertEq(deployerAddress.balance, DEPLOYER_INITIAL_ETH_BALANCE);

    // Get a reference to the Uniswap V3 Factory contract and WETH
    IUniswapV3Factory uniswapFactory = IUniswapV3Factory(0x1F98431c8aD98523631AE4a59f267346ea31F984);
    IWETH weth = IWETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    // Deployer wraps ETH in WETH
    weth.deposit{value: UNISWAP_INITIAL_WETH_LIQUIDITY}();
    assertEq(weth.balanceOf(deployerAddress), UNISWAP_INITIAL_WETH_LIQUIDITY);

    /*
      // Deploy DVT token. This is the token to be traded against WETH in the Uniswap v3 pool.
      token = await (await ethers.getContractFactory('DamnValuableToken', deployer)).deploy();

      // Create the Uniswap v3 pool
      uniswapPositionManager = new ethers.Contract("0xC36442b4a4522E871399CD717aBDD847Ab11FE88", positionManagerJson.abi, deployer);
      const FEE = 3000; // 0.3%
      await uniswapPositionManager.createAndInitializePoolIfNecessary(
          weth.address,  // token0
          token.address, // token1
          FEE,
          encodePriceSqrt(1, 1),
          { gasLimit: 5000000 }
      );

      let uniswapPoolAddress = await uniswapFactory.getPool(
          weth.address,
          token.address,
          FEE
      );
      uniswapPool = new ethers.Contract(uniswapPoolAddress, poolJson.abi, deployer);
      await uniswapPool.increaseObservationCardinalityNext(40);

      // Deployer adds liquidity at current price to Uniswap V3 exchange
      await weth.approve(uniswapPositionManager.address, ethers.constants.MaxUint256);
      await token.approve(uniswapPositionManager.address, ethers.constants.MaxUint256);
      await uniswapPositionManager.mint({
          token0: weth.address,
          token1: token.address,
          tickLower: -60,
          tickUpper: 60,
          fee: FEE,
          recipient: deployer.address,
          amount0Desired: UNISWAP_INITIAL_WETH_LIQUIDITY,
          amount1Desired: UNISWAP_INITIAL_TOKEN_LIQUIDITY,
          amount0Min: 0,
          amount1Min: 0,
          deadline: (await ethers.provider.getBlock('latest')).timestamp * 2,
      }, { gasLimit: 5000000 });

      // Deploy the lending pool
      lendingPool = await (await ethers.getContractFactory('PuppetV3Pool', deployer)).deploy(
          weth.address,
          token.address,
          uniswapPool.address
      );

      // Setup initial token balances of lending pool and player
      await token.transfer(player.address, PLAYER_INITIAL_TOKEN_BALANCE);
      await token.transfer(lendingPool.address, LENDING_POOL_INITIAL_TOKEN_BALANCE);

      // Some time passes
      await time.increase(3 * 24 * 60 * 60); // 3 days in seconds

      // Ensure oracle in lending pool is working as expected. At this point, DVT/WETH price should be 1:1.
      // To borrow 1 DVT, must deposit 3 ETH
      expect(
          await lendingPool.calculateDepositOfWETHRequired(1n * 10n ** 18n)
      ).to.be.eq(3n * 10n ** 18n);

      // To borrow all DVT in lending pool, user must deposit three times its value
      expect(
          await lendingPool.calculateDepositOfWETHRequired(LENDING_POOL_INITIAL_TOKEN_BALANCE)
      ).to.be.eq(LENDING_POOL_INITIAL_TOKEN_BALANCE * 3n);

      // Ensure player doesn't have that much ETH
      expect(await ethers.provider.getBalance(player.address)).to.be.lt(LENDING_POOL_INITIAL_TOKEN_BALANCE * 3n);

      initialBlockTimestamp = (await ethers.provider.getBlock('latest')).timestamp;
    */
    vm.stopPrank();
  }

  function validate() public {
  /*
    // Block timestamp must not have changed too much
    expect(
        (await ethers.provider.getBlock('latest')).timestamp - initialBlockTimestamp
    ).to.be.lt(115, 'Too much time passed');

    // Player has taken all tokens out of the pool
    expect(
        await token.balanceOf(lendingPool.address)
    ).to.be.eq(0);
    expect(
        await token.balanceOf(player.address)
    ).to.be.gte(LENDING_POOL_INITIAL_TOKEN_BALANCE);
  */
  }
}

