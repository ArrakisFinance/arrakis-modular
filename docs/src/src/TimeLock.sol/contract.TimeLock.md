# TimeLock
[Git Source](https://github.com/ArrakisFinance/arrakis-modular/blob/4485c572ded3a830c181fa38ceaac13efe8eb7f1/src/TimeLock.sol)

**Inherits:**
TimelockController, [ITimeLock](/src/interfaces/ITimeLock.sol/interface.ITimeLock.md)


## Functions
### constructor


```solidity
constructor(
    uint256 minDelay,
    address[] memory proposers,
    address[] memory executors,
    address admin
) TimelockController(minDelay, proposers, executors, admin);
```

### updateDelay

*override updateDelay function of TimelockController to not allow
update of delay.*


```solidity
function updateDelay(uint256) external pure override;
```

