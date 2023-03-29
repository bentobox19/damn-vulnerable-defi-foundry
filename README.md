# damn-vulnerable-defi-foundry

* Porting in [foundry-rs](https://github.com/foundry-rs/foundry) of the solutions for [The Damn Vulnerable DeFi CTF](https://www.damnvulnerabledefi.xyz/).

## Writeups

* Discussion of the solutions at the [writeups.md](writeups.md) document.

## Install forge

* Follow the [instructions](https://book.getfoundry.sh/getting-started/installation.html) to install [Foundry](https://github.com/foundry-rs/foundry).

## Install dependencies

```bash
forge install
```

## Run the entire test suit

```bash
forge test
```

## Running a single challenge

```bash
forge test --match-contract Unstoppable
```

### Add traces

There are different level of verbosities, `-vvvvv` is the maximum.

```bash
forge test --match-contract Unstoppable -vvvvv
```
