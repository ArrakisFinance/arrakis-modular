# arrakis-modular

## Install

install deps with:

```bash
forge install
```

if you get permission issues installing submodules then add this to your `~/.gitconfig` file:

```
[url "https://github.com/"]
	insteadOf = git@github.com:
```

## Compile

compile contracts with:

```bash
forge compile
```

there will be a bunch of warnings (for test contracts)

if you get an error about IClaims interface then just MANUALLY add `view` to balanceOf function in IClaims interface here `lib/periphery-next/lib/v4-core/src/interfaces/ICLaims.sol`

after adding view should look like:

```
function balanceOf(address account, Currency currency) external view returns (uint256);
```

## Test

first create .env file with

```bash
touch .env
```

then add these lines into your `.env` file:

```
ETH_RPC_URL="https://eth-mainnet.alchemyapi.io/v2/<YOUR-API-KEY-HERE>"
ETH_BLOCK_NUMBER=18039585
```

finally you can run 

```bash
forge test -vv
```

and tests should succeed!
