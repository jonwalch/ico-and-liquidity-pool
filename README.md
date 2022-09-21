# LP Project

I wrote these two project as part of the Macro Smart Contract Security Engineering Fellowship. https://0xmacro.com/engineering-fellowship
I combined the two for convenience.

## Technical Spec
<!-- Here you should list the technical requirements of the project. These should include the points given in the project spec, but will go beyond what is given in the spec because that was written by a non-technical client who leaves it up to you to fill in the spec's details -->

Added withdraw function to ICO contract that allows treasury to move the invested funds out of the ICO contract and into the treasury address.

Liquidity Pool Contract:

Events are emitted for Mint, Burn, and Swap
Mint, burn, and swap are all guarded from reentrancy. A malicious contract, on receiving ether, could call back into one of the functions before the
reserve amounts were updated, which would result in the math being wrong.
All 3 functions use balances and reserves to calculate values owed.

ERC-20 contract for your pool's LP tokens
mint - Mints LP tokens for liquidity deposits (ETH + SPC tokens).
burn - Burns LP tokens to return liquidity to holder. 
swap - Accepts trades with a 1% fee. enforces 1% when checking K.

Router Contract:
All functions have configurable deadlines to execute.

Transferring tokens to an LP pool requires two transactions:

Trader grants allowance on the Router contract for Y tokens.
Trader executes addLiquidity which pulls the funds from the Trader and transfers them to the LP Pool.

addLiquidity - Reverts if amounts are below amountMinSpc or amountMinEth. Returns excess ether to caller.
removeLiquidity- Calls transferFrom from caller to pool to move SPCLP tokens. Reverts if amounts are below amountMinSpc or amountMinEth. 

swapEthForSpc - payable, sends ether to pool. Enforces spcOutMin.
swapSpcForEth - caller must approve router on ico contract. calls ico.transferFrom to move Spc from caller to pool. Enforces ethOutMin.
Both of these call _swap. _swap calculates amount sentin and out. sends out amounts to pool.

other functions are internal for convenience
spcToEthPrice - is for the swap value on the frontend

There's a frontend that:

Allow users to deposit ETH and SPC for LP tokens (and vice-versa)
Allow users to trade ETH for SPC (and vice-versa)
Configure max slippage
Show the estimated trade value they will be receiving

## Notes For self
Generate coverage report with:
```
forge coverage --report lcov && genhtml lcov.info -o report --branch-coverage && open report/index.html
```

Deploy to rinkeby:
```
forge script script/Router.s.sol:RouterScript --rpc-url $RINKEBY_RPC_URL  --private-key $PRIVATE_KEY --broadcast --verify --etherscan-api-key $ETHERSCAN_KEY -vvvv
```

If verify doesn't work, rerun above command but remove `--broadcast`

Deploy locally:

`anvil`

Then 

```
forge script script/Router.s.sol:RouterScript --fork-url http://localhost:8545 \
--private-key $PRIVATE_KEY0 --broadcast #$PRIVATE_KEY0 is copied from anvil output
```