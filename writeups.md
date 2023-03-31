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

The assembly code at `totalAssets()`:

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

### References

* https://eips.ethereum.org/EIPS/eip-4626
* https://ethereum.org/es/developers/docs/standards/tokens/erc-4626/
* https://eips.ethereum.org/EIPS/eip-3156
