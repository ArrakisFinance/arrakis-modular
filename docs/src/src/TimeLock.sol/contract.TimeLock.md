# TimeLock
[Git Source](https://github.com/ArrakisFinance/arrakis-modular/blob/22c7b5c5fce6ff4d3a051aa4fbf376745815e340/src/TimeLock.sol)

**Inherits:**
TimelockController, [ITimeLock](/src/interfaces/ITimeLock.sol/interface.ITimeLock.md)


## Functions
### constructor


```solidity
constructor(uint256 minDelay, address[] memory proposers, address[] memory executors, address admin)
    TimelockController(minDelay, proposers, executors, admin);
```

### updateDelay

*override updateDelay function of TimelockController to not allow
update of delay.*


```solidity
function updateDelay(uint256) external pure override;
```

