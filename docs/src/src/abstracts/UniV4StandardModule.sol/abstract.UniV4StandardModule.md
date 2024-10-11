# UniV4StandardModule
[Git Source](https://github.com/ArrakisFinance/arrakis-modular/blob/4485c572ded3a830c181fa38ceaac13efe8eb7f1/src/abstracts/UniV4StandardModule.sol)

**Inherits:**
ReentrancyGuardUpgradeable, PausableUpgradeable, [IArrakisLPModule](/src/interfaces/IArrakisLPModule.sol/interface.IArrakisLPModule.md), [IArrakisLPModuleID](/src/interfaces/IArrakisLPModuleID.sol/interface.IArrakisLPModuleID.md), [IUniV4StandardModule](/src/interfaces/IUniV4StandardModule.sol/interface.IUniV4StandardModule.md), IUnlockCallback

this module can only set uni v4 pool that have generic hook,
that don't require specific action to become liquidity provider.

*due to native coin standard difference between uni V4 and arrakis,
we are assuming that all inputed amounts are using arrakis vault token0/token1
as reference. Internal logic of UniV4StandardModule will handle the conversion or
use the poolKey to interact with the poolManager.*


## State Variables
### poolManager
function used to get the uniswap v4 pool manager.


```solidity
IPoolManager public immutable poolManager;
```


### _guardian

```solidity
address internal immutable _guardian;
```


### metaVault
module's metaVault as IArrakisMetaVault.


```solidity
IArrakisMetaVault public metaVault;
```


### token0
module's token0 as IERC20Metadata.


```solidity
IERC20Metadata public token0;
```


### token1
module's token1 as IERC20Metadata.


```solidity
IERC20Metadata public token1;
```


### isInversed
boolean to know if the poolKey's currencies pair are inversed.


```solidity
bool public isInversed;
```


### managerFeePIPS
manager fees share.


```solidity
uint256 public managerFeePIPS;
```


### oracle
oracle that will be used to proctect rebalances against attacks.


```solidity
IOracleWrapper public oracle;
```


### maxSlippage
max slippage that can occur during swap rebalance.


```solidity
uint24 public maxSlippage;
```


### poolKey
pool's key of the module.


```solidity
PoolKey public poolKey;
```


### _init0

```solidity
uint256 internal _init0;
```


### _init1

```solidity
uint256 internal _init1;
```


### _ranges

```solidity
Range[] internal _ranges;
```


### _activeRanges

```solidity
mapping(bytes32 => bool) internal _activeRanges;
```


## Functions
### onlyManager


```solidity
modifier onlyManager();
```

### onlyMetaVault


```solidity
modifier onlyMetaVault();
```

### onlyGuardian


```solidity
modifier onlyGuardian();
```

### constructor


```solidity
constructor(address poolManager_, address guardian_);
```

### pause

function used to pause the module.

*only callable by guardian*


```solidity
function pause() external whenNotPaused onlyGuardian;
```

### unpause

function used to unpause the module.

*only callable by guardian*


```solidity
function unpause() external whenPaused onlyGuardian;
```

### initialize

initialize function to delegate call onced the beacon proxy is deployed,
for initializing the uniswap v4 standard module.

*this function will deposit fund as left over on poolManager.*


```solidity
function initialize(
    uint256 init0_,
    uint256 init1_,
    bool isInversed_,
    PoolKey calldata poolKey_,
    IOracleWrapper oracle_,
    uint24 maxSlippage_,
    address metaVault_
) external initializer;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`init0_`|`uint256`|initial amount of token0 to provide to uniswap standard module.|
|`init1_`|`uint256`|initial amount of token1 to provide to valantis module.|
|`isInversed_`|`bool`|boolean to check if the poolKey's currencies pair are inversed, compared to the module's tokens pair.|
|`poolKey_`|`PoolKey`|pool key of the uniswap v4 pool that will be used by the module.|
|`oracle_`|`IOracleWrapper`|address of the oracle used by the uniswap v4 standard module.|
|`maxSlippage_`|`uint24`|allowed to manager for rebalancing the inventory using swap.|
|`metaVault_`|`address`|address of the meta vault|


### initializePosition

function used to initialize the module
when a module switch happen

*check if the pool is initialized.*


```solidity
function initializePosition(bytes calldata) external onlyMetaVault;
```

### setPool

function used to set the pool for the module.

*put tokens into poolManager*


```solidity
function setPool(
    PoolKey calldata poolKey_,
    LiquidityRange[] calldata liquidityRanges_,
    SwapPayload calldata swapPayload_
) external onlyManager nonReentrant;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`poolKey_`|`PoolKey`|pool key of the uniswap v4 pool that will be used by the module.|
|`liquidityRanges_`|`LiquidityRange[]`|list of liquidity ranges to be used by the module on the new pool.|
|`swapPayload_`|`SwapPayload`|swap payload to be used during rebalance.|


### withdraw

function used by metaVault to withdraw tokens from the strategy.

*check if the pool is initialized.*

*salt will be emty string on the module.*


```solidity
function withdraw(
    address receiver_,
    uint256 proportion_
)
    external
    onlyMetaVault
    nonReentrant
    returns (uint256 amount0, uint256 amount1);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`receiver_`|`address`|address that will receive tokens.|
|`proportion_`|`uint256`|number of share needed to be withdrawn.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`amount0`|`uint256`|amount of token0 withdrawn.|
|`amount1`|`uint256`|amount of token1 withdrawn.|


### rebalance

function used to rebalance the inventory of the module.


```solidity
function rebalance(
    LiquidityRange[] memory liquidityRanges_,
    SwapPayload memory swapPayload_
)
    public
    onlyManager
    nonReentrant
    returns (
        uint256 amount0Minted,
        uint256 amount1Minted,
        uint256 amount0Burned,
        uint256 amount1Burned
    );
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`liquidityRanges_`|`LiquidityRange[]`|list of liquidity ranges to be used by the module.|
|`swapPayload_`|`SwapPayload`|swap payload to be used during rebalance.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`amount0Minted`|`uint256`|amount of token0 minted.|
|`amount1Minted`|`uint256`|amount of token1 minted.|
|`amount0Burned`|`uint256`|amount of token0 burned.|
|`amount1Burned`|`uint256`|amount of token1 burned.|


### withdrawManagerBalance

function used by metaVault or manager to get manager fees.


```solidity
function withdrawManagerBalance()
    external
    nonReentrant
    returns (uint256 amount0, uint256 amount1);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`amount0`|`uint256`|amount of token0 sent to manager.|
|`amount1`|`uint256`|amount of token1 sent to manager.|


### setManagerFeePIPS

function used to set manager fees.

*default swapPayload, no swap happens here.
swapPayload will be empty. And will use it to do rebalance and collect fees.*


```solidity
function setManagerFeePIPS(uint256 newFeePIPS_)
    external
    onlyManager;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newFeePIPS_`|`uint256`|new fee that will be applied.|


### receive


```solidity
receive() external payable;
```

### guardian

function used to get the address that can pause the module.


```solidity
function guardian() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|guardian address of the pauser.|


### getRanges

function used to get the list of active ranges.


```solidity
function getRanges() external view returns (Range[] memory ranges);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`ranges`|`Range[]`|active ranges|


### getInits

function used to get the initial amounts needed to open a position.


```solidity
function getInits()
    external
    view
    returns (uint256 init0, uint256 init1);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`init0`|`uint256`|the amount of token0 needed to open a position.|
|`init1`|`uint256`|the amount of token1 needed to open a position.|


### totalUnderlying

function used to get the amount of token0 and token1 sitting
on the position.


```solidity
function totalUnderlying()
    external
    view
    returns (uint256 amount0, uint256 amount1);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`amount0`|`uint256`|the amount of token0 sitting on the position.|
|`amount1`|`uint256`|the amount of token1 sitting on the position.|


### totalUnderlyingAtPrice

function used to get the amounts of token0 and token1 sitting
on the position for a specific price.


```solidity
function totalUnderlyingAtPrice(uint160 priceX96_)
    external
    view
    returns (uint256 amount0, uint256 amount1);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`priceX96_`|`uint160`|price at which we want to simulate our tokens composition|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`amount0`|`uint256`|the amount of token0 sitting on the position for priceX96.|
|`amount1`|`uint256`|the amount of token1 sitting on the position for priceX96.|


### validateRebalance

function used to validate if module state is not manipulated
before rebalance.


```solidity
function validateRebalance(
    IOracleWrapper oracle_,
    uint24 maxDeviation_
) external view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`oracle_`|`IOracleWrapper`|oracle that will used to check internal state.|
|`maxDeviation_`|`uint24`|maximum deviation allowed. rebalance can happen.|


### managerBalance0

function used to get manager token0 balance.

*amount of fees in token0 that manager have not taken yet.*


```solidity
function managerBalance0()
    external
    view
    returns (uint256 managerFee0);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`managerFee0`|`uint256`|amount of token0 that manager earned.|


### managerBalance1

function used to get manager token1 balance.

*amount of fees in token1 that manager have not taken yet.*


```solidity
function managerBalance1()
    external
    view
    returns (uint256 managerFee1);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`managerFee1`|`uint256`|amount of token1 that manager earned.|


### _unlockCallback


```solidity
function _unlockCallback(
    IPoolManager _poolManager,
    Action action,
    bytes memory data
) internal returns (bytes memory);
```

### _withdraw

*initialize position.*


```solidity
function _withdraw(Withdraw memory withdraw_)
    internal
    returns (bytes memory result);
```

### _internalRebalance

*multiply -1 because we will remove liquidity.*

*if receiver is a smart contract, the sm should implement receive
fallback function.*

*if proportion is 100% we take all fees, to prevent
rounding errors.*


```solidity
function _internalRebalance(
    LiquidityRange[] memory liquidityRanges_,
    SwapPayload memory swapPayload_
)
    internal
    returns (
        uint256 amount0Minted,
        uint256 amount1Minted,
        uint256 amount0Burned,
        uint256 amount1Burned
    );
```

### _rebalance


```solidity
function _rebalance(
    IPoolManager poolManager_,
    LiquidityRange[] memory liquidityRanges_,
    SwapPayload memory swapPayload_
) internal returns (bytes memory result);
```

### _initializePosition

*here we are reasonning in term of token0 and token1 of vault (not poolKey).*


```solidity
function _initializePosition(IPoolManager poolManager_)
    internal
    returns (bytes memory result);
```

### _collectFee

*no need to use Address lib for PoolManager.*


```solidity
function _collectFee(
    PoolKey memory poolKey_,
    PoolId poolId_,
    int24 tickLower_,
    int24 tickUpper_
) internal;
```

### _addLiquidity


```solidity
function _addLiquidity(
    PoolKey memory poolKey_,
    PoolId poolId_,
    uint128 liquidityToAdd_,
    int24 tickLower_,
    int24 tickUpper_
) internal returns (uint256 amount0, uint256 amount1);
```

### _removeLiquidity


```solidity
function _removeLiquidity(
    PoolKey memory poolKey_,
    PoolId poolId_,
    uint128 liquidityToRemove_,
    int24 tickLower_,
    int24 tickUpper_
) internal returns (uint256 amount0, uint256 amount1);
```

### _get6909Balances


```solidity
function _get6909Balances()
    internal
    view
    returns (
        uint256 currency0Id,
        uint256 leftOver0,
        uint256 currency1Id,
        uint256 leftOver1
    );
```

### _checkCurrencyBalances


```solidity
function _checkCurrencyBalances()
    internal
    view
    returns (uint256, uint256);
```

### _checkCurrencyDelta


```solidity
function _checkCurrencyDelta(
    int256 currency0BalanceRaw_,
    int256 currency1BalanceRaw_
) internal view returns (uint256, uint256);
```

### _getRangeIndex


```solidity
function _getRangeIndex(
    int24 tickLower_,
    int24 tickUpper_
) internal view returns (uint256, uint256);
```

### _getPoolRanges


```solidity
function _getPoolRanges(uint256 length_)
    internal
    view
    returns (PoolRange[] memory poolRanges);
```

### _checkTicks


```solidity
function _checkTicks(
    int24 tickLower_,
    int24 tickUpper_
) internal pure;
```

### _getTokens


```solidity
function _getTokens(PoolKey memory poolKey_)
    internal
    view
    returns (address token0, address token1);
```

### _checkTokens


```solidity
function _checkTokens(
    PoolKey memory poolKey_,
    address token0_,
    address token1_,
    bool isInversed_
) internal pure;
```

### _checkPermissions

*Currency.unwrap(poolKey_.currency1) == address(0) is not possible*

*because currency0 should be lower currency1.*


```solidity
function _checkPermissions(PoolKey memory poolKey_)
    internal
    virtual;
```

### _checkMinReturn


```solidity
function _checkMinReturn(
    bool zeroForOne_,
    uint256 expectedMinReturn_,
    uint256 amountIn_,
    uint8 decimals0_,
    uint8 decimals1_
) internal view;
```

## Enums
### Action

```solidity
enum Action {
    WITHDRAW,
    REBALANCE,
    INITIALIZE_POSITION,
    DEPOSIT_FUND
}
```

