# Guardian
[Git Source](https://github.com/ArrakisFinance/arrakis-modular/blob/9091a6ee814f061039fd7b968feddb93bbdf1110/src/Guardian.sol)

**Inherits:**
Ownable, [IGuardian](/src/interfaces/IGuardian.sol/interface.IGuardian.md)


## State Variables
### pauser

```solidity
address public pauser;
```


## Functions
### constructor


```solidity
constructor(address owner_, address pauser_);
```

### setPauser

function to set the pauser of Arrakis protocol.


```solidity
function setPauser(address newPauser_) external onlyOwner;
```

