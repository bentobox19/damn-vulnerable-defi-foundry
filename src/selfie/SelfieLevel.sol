// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "forge-std/Test.sol";
// import "forge-std/Vm.sol";

import "./SelfiePool.sol";

contract SelfieLevel is StdAssertions {
  // Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));
  // address payable private constant deployer = payable(address(uint160(uint256(keccak256(abi.encodePacked("deployer"))))));

  // uint256 internal constant ETHER_IN_POOL = 1_000e18;
  // uint256 internal constant PLAYER_INITIAL_ETH_BALANCE = 1e18;

  // SideEntranceLenderPool public pool;


/*
    let deployer, player;
    let token, governance, pool;

    const TOKEN_INITIAL_SUPPLY = 2000000n * 10n ** 18n;
    const TOKENS_IN_POOL = 1500000n * 10n ** 18n;

*/
  function setup() external {


/*
        [deployer, player] = await ethers.getSigners();

        // Deploy Damn Valuable Token Snapshot
        token = await (await ethers.getContractFactory('DamnValuableTokenSnapshot', deployer)).deploy(TOKEN_INITIAL_SUPPLY);

        // Deploy governance contract
        governance = await (await ethers.getContractFactory('SimpleGovernance', deployer)).deploy(token.address);
        expect(await governance.getActionCounter()).to.eq(1);

        // Deploy the pool
        pool = await (await ethers.getContractFactory('SelfiePool', deployer)).deploy(
            token.address,
            governance.address
        );
        expect(await pool.token()).to.eq(token.address);
        expect(await pool.governance()).to.eq(governance.address);

        // Fund the pool
        await token.transfer(pool.address, TOKENS_IN_POOL);
        await token.snapshot();
        expect(await token.balanceOf(pool.address)).to.be.equal(TOKENS_IN_POOL);
        expect(await pool.maxFlashLoan(token.address)).to.eq(TOKENS_IN_POOL);
        expect(await pool.flashFee(token.address, 0)).to.eq(0);
*/
  }

  function validate() external {


/*
        // Player has taken all tokens from the pool
        expect(
            await token.balanceOf(player.address)
        ).to.be.equal(TOKENS_IN_POOL);
        expect(
            await token.balanceOf(pool.address)
        ).to.be.equal(0);
*/
  }
}