# ArrakisPrivateHook
[Git Source](https://github.com/ArrakisFinance/arrakis-modular/blob/4485c572ded3a830c181fa38ceaac13efe8eb7f1/src/hooks/ArrakisPrivateHook.sol)

**Inherits:**
IHooks, [IArrakisPrivateHook](/src/interfaces/IArrakisPrivateHook.sol/interface.IArrakisPrivateHook.md)


## State Variables
### module

```solidity
address public immutable module;
```


### poolManager

```solidity
address public immutable poolManager;
```


### vault

```solidity
address public immutable vault;
```


### manager

```solidity
address public immutable manager;
```


### fee

```solidity
uint24 public fee;
```


## Functions
### constructor


```solidity
constructor(address module_, address poolManager_);
```

### setFee


```solidity
function setFee(PoolKey calldata poolKey_, uint24 fee_) external;
```

### beforeInitialize

The hook called before the state of a pool is initialized.

*function not implemented, ArrakisPrivateHook will not support this hook.*


```solidity
function beforeInitialize(
    address,
    PoolKey calldata,
    uint160,
    bytes calldata
) external virtual returns (bytes4);
```

### afterInitialize

The hook called after the state of a pool is initialized.

*function not implemented, ArrakisPrivateHook will not support this hook.*


```solidity
function afterInitialize(
    address,
    PoolKey calldata,
    uint160,
    int24,
    bytes calldata
) external virtual returns (bytes4);
```

### beforeAddLiquidity

The hook called before liquidity is added


```solidity
function beforeAddLiquidity(
    address sender,
    PoolKey calldata,
    IPoolManager.ModifyLiquidityParams calldata,
    bytes calldata
) external virtual returns (bytes4);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`sender`|`address`|The initial msg.sender for the add liquidity call.|
|`<none>`|`PoolKey`||
|`<none>`|`IPoolManager.ModifyLiquidityParams`||
|`<none>`|`bytes`||


### afterAddLiquidity

The hook called after liquidity is added.

*function not implemented, ArrakisPrivateHook will not support this hook.*


```solidity
function afterAddLiquidity(
    address,
    PoolKey calldata,
    IPoolManager.ModifyLiquidityParams calldata,
    BalanceDelta,
    BalanceDelta,
    bytes calldata
) external virtual returns (bytes4, BalanceDelta);
```

### beforeRemoveLiquidity

The hook called before liquidity is removed.


```solidity
function beforeRemoveLiquidity(
    address sender,
    PoolKey calldata,
    IPoolManager.ModifyLiquidityParams calldata,
    bytes calldata
) external virtual returns (bytes4);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`sender`|`address`|The initial msg.sender for the remove liquidity call.|
|`<none>`|`PoolKey`||
|`<none>`|`IPoolManager.ModifyLiquidityParams`||
|`<none>`|`bytes`||


### afterRemoveLiquidity

The hook called after liquidity is removed.

*function not implemented, ArrakisPrivateHook will not support this hook.*


```solidity
function afterRemoveLiquidity(
    address,
    PoolKey calldata,
    IPoolManager.ModifyLiquidityParams calldata,
    BalanceDelta,
    BalanceDelta,
    bytes calldata
) external virtual returns (bytes4, BalanceDelta);
```

### beforeSwap

The hook called before a swap.

*function not implemented, ArrakisPrivateHook will not support this hook.*


```solidity
function beforeSwap(
    address,
    PoolKey calldata,
    IPoolManager.SwapParams calldata,
    bytes calldata
) external virtual returns (bytes4, BeforeSwapDelta, uint24);
```

### afterSwap

The hook called after a swap.

*function not implemented, ArrakisPrivateHook will not support this hook.*


```solidity
function afterSwap(
    address,
    PoolKey calldata,
    IPoolManager.SwapParams calldata,
    BalanceDelta,
    bytes calldata
) external virtual returns (bytes4, int128);
```

### beforeDonate

The hook called before donate.

*function not implemented, ArrakisPrivateHook will not support this hook.*


```solidity
function beforeDonate(
    address,
    PoolKey calldata,
    uint256,
    uint256,
    bytes calldata
) external virtual returns (bytes4);
```

### afterDonate

The hook called after donate.

*function not implemented, ArrakisPrivateHook will not support this hook.*


```solidity
function afterDonate(
    address,
    PoolKey calldata,
    uint256,
    uint256,
    bytes calldata
) external virtual returns (bytes4);
```

