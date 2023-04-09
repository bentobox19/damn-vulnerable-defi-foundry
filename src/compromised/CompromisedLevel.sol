// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "forge-std/Test.sol";

import "./TrustfulOracleInitializer.sol";
import "./Exchange.sol";

contract CompromisedLevel is StdAssertions {
  Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));
  address payable private constant deployer = payable(address(uint160(uint256(keccak256(abi.encodePacked("deployer"))))));

  uint256 internal constant TRUSTED_SOURCE_INITIAL_ETH_BALANCE = 2e18;
  uint256 internal constant PLAYER_INITIAL_ETH_BALANCE = 1e17;
  uint256 internal constant INITIAL_NFT_PRICE = 999e18;
  uint256 internal constant EXCHANGE_INITIAL_ETH_BALANCE = 999e18;

  TrustfulOracle public oracle;
  Exchange public exchange;
  DamnValuableNFT public nftToken;

  function setup() external {
    vm.startPrank(deployer);
    vm.deal(deployer, EXCHANGE_INITIAL_ETH_BALANCE);

    address[] memory sources = new address[](3);
    sources[0] = 0xA73209FB1a42495120166736362A1DfA9F95A105;
    sources[1] = 0xe92401A4d3af5E446d93D11EEc806b1462b39D15;
    sources[2] = 0x81A5D6E50C214044bE44cA0CB057fe119097850c;

    for(uint8 i = 0; i < sources.length; i++) {
      vm.deal(sources[i], TRUSTED_SOURCE_INITIAL_ETH_BALANCE);
      assertEq(sources[i].balance, TRUSTED_SOURCE_INITIAL_ETH_BALANCE);
    }

    // Player starts with limited balance
    vm.deal(msg.sender, PLAYER_INITIAL_ETH_BALANCE);
    assertEq(msg.sender.balance, PLAYER_INITIAL_ETH_BALANCE);

    // Deploy the oracle and setup the trusted sources with initial prices
    string[] memory symbols = new string[](3);
    for(uint i = 0; i < 3; i++) {
      symbols[i] = "DVNFT";
    }
    uint256[] memory initialPrices = new uint256[](3);
    for(uint i = 0; i < 3; i++) {
      initialPrices[i] = INITIAL_NFT_PRICE;
    }
    oracle = new TrustfulOracleInitializer(sources, symbols, initialPrices).oracle();

    // Deploy the exchange and get an instance to the associated ERC721 token
    exchange = new Exchange{value: EXCHANGE_INITIAL_ETH_BALANCE}(address(oracle));
    nftToken = exchange.token();
    assertEq(nftToken.owner(), 0x0000000000000000000000000000000000000000); // ownership renounced
    assertEq(nftToken.rolesOf(address(exchange)), nftToken.MINTER_ROLE());

    vm.stopPrank();
  }

  function validate() external {
    // drain the exchange
    assertEq(address(exchange).balance, 0);
    assertGt(msg.sender.balance, EXCHANGE_INITIAL_ETH_BALANCE);

    // player doesn't own any NFT
    assertEq(nftToken.balanceOf(msg.sender), 0);
    // median price doesn't vary
    assertEq(oracle.getMedianPrice("DVNFT"), INITIAL_NFT_PRICE);
  }
}
