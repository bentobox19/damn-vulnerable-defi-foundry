// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "forge-std/Test.sol";
import "solmate/src/tokens/WETH.sol";
import "dvt/DamnValuableNFT.sol";
import "dvt/DamnValuableToken.sol";
import "./FreeRiderNFTMarketplace.sol";
import "./FreeRiderRecovery.sol";

import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

contract FreeRiderLevel is StdAssertions, StdCheats {
  Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));
  address payable private constant deployer = payable(address(uint160(uint256(keccak256(abi.encodePacked("deployer"))))));
  address payable private constant devs = payable(address(uint160(uint256(keccak256(abi.encodePacked("devs"))))));

  // The NFT marketplace will have 6 tokens, at 15 ETH each
  uint256 internal constant NFT_PRICE = 15e18;
  uint256 internal constant AMOUNT_OF_NFTS = 6;
  uint256 internal constant MARKETPLACE_INITIAL_ETH_BALANCE = 90e18;

  uint256 internal constant PLAYER_INITIAL_ETH_BALANCE = 1e17;

  uint256 internal constant BOUNTY = 45e18;

  // Initial reserves for the Uniswap v2 pool
  uint256 internal constant UNISWAP_INITIAL_TOKEN_RESERVE = 15_000e18;
  uint256 internal constant UNISWAP_INITIAL_WETH_RESERVE = 9_000e18;

  WETH internal weth;
  DamnValuableNFT internal nft;
  DamnValuableToken internal token;
  FreeRiderNFTMarketplace internal marketplace;
  FreeRiderRecovery internal devsContract;
  IUniswapV2Factory internal uniswapFactory;
  IUniswapV2Pair internal uniswapPair;
  IUniswapV2Router01 internal uniswapRouter;

  function setup() external {
    vm.startPrank(deployer);
    vm.deal(deployer,
      UNISWAP_INITIAL_WETH_RESERVE +
      MARKETPLACE_INITIAL_ETH_BALANCE
    );

    // Player starts with limited ETH balance
    vm.deal(msg.sender, PLAYER_INITIAL_ETH_BALANCE);
    assertEq(msg.sender.balance, PLAYER_INITIAL_ETH_BALANCE);

    // Deploy WETH
    weth = new WETH();

    // Deploy token to be traded against WETH in Uniswap v2
    token = new DamnValuableToken();

    // Deploy Uniswap Factory and Router
    // why with deployCode() you ask?
    // To avoid problems with the version police!
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

    // Approve tokens, and then create Uniswap v2 pair against WETH and add liquidity
    // The function takes care of deploying the pair automatically
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

    // Get a reference to the created Uniswap pair
    uniswapPair = IUniswapV2Pair(
      uniswapFactory.getPair(address(token), address(weth))
    );
    assertEq(uniswapPair.token0(), address(weth));
    assertEq(uniswapPair.token1(), address(token));
    assertGt(uniswapPair.balanceOf(address(deployer)), 0);

    // Deploy the marketplace and get the associated ERC721 token
    // The marketplace will automatically mint AMOUNT_OF_NFTS to the deployer
    // (see `FreeRiderNFTMarketplace::constructor`)
    marketplace =
      new FreeRiderNFTMarketplace
        {value: MARKETPLACE_INITIAL_ETH_BALANCE}
        (AMOUNT_OF_NFTS);

    // Operate with NFT contract in marketplace
    nft = DamnValuableNFT(marketplace.token());
    assertEq(nft.owner(), 0x0000000000000000000000000000000000000000);
    assertEq(nft.rolesOf(address(marketplace)), nft.MINTER_ROLE());

    // Ensure deployer owns all minted NFTs. Then approve the marketplace to trade them.
    for (uint id = 0; id < AMOUNT_OF_NFTS; id++) {
      assertEq(nft.ownerOf(id), address(deployer));
    }
    nft.setApprovalForAll(address(marketplace), true);

    // Open offers in the marketplace
    uint256[] memory tokenIds = new uint256[](6);
    uint256[] memory prices = new uint256[](6);
    for (uint i = 0; i < 6; i++) {
        tokenIds[i] = i;
        prices[i] = NFT_PRICE;
    }
    marketplace.offerMany(tokenIds, prices);
    assertEq(marketplace.offersCount(), 6);

    vm.stopPrank();

    vm.startPrank(devs);
    vm.deal(devs, BOUNTY);

    // Deploy devs' contract, adding the player as the beneficiary
    devsContract =
      new FreeRiderRecovery
        { value: BOUNTY }
        (address(msg.sender), address(nft));

    vm.stopPrank();
  }

  function validate() external {
    // The devs extract all NFTs from its associated contract
    vm.startPrank(devs);
    for (uint tokenId = 0; tokenId < AMOUNT_OF_NFTS; tokenId++) {
      nft.transferFrom(address(devsContract), address(devs), tokenId);
      assertEq(nft.ownerOf(tokenId), address(devs));
    }
    vm.stopPrank();

    // Exchange must have lost NFTs and ETH
    assertEq(marketplace.offersCount(), 0);
    assertLt(address(marketplace).balance,
      MARKETPLACE_INITIAL_ETH_BALANCE);

    // Player must have earned all ETH
    assertGt(address(msg.sender).balance, BOUNTY);
    assertEq(address(devsContract).balance, 0);
  }
}
