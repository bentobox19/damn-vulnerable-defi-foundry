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

???

### References

* ???
