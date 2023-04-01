# Write Ups

<!-- MarkdownTOC levels="1,2" autolink="true" -->

- [01 Unstoppable](#01-unstoppable)

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
