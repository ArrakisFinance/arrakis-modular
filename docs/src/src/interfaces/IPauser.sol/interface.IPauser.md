# IPauser
[Git Source](https://github.com/ArrakisFinance/arrakis-modular/blob/4485c572ded3a830c181fa38ceaac13efe8eb7f1/src/interfaces/IPauser.sol)


## Functions
### pause


```solidity
function pause(address target_) external;
```

### whitelistPausers


```solidity
function whitelistPausers(address[] calldata pausers_) external;
```

### blacklistPausers


```solidity
function blacklistPausers(address[] calldata pausers_) external;
```

### isPauser


```solidity
function isPauser(address account) external view returns (bool);
```

## Events
### LogPauserWhitelisted

```solidity
event LogPauserWhitelisted(address[] indexed pauser);
```

### LogPauserBlacklisted

```solidity
event LogPauserBlacklisted(address[] indexed pauser);
```

### LogPause

```solidity
event LogPause(address indexed target);
```

## Errors
### AddressZero

```solidity
error AddressZero();
```

### AlreadyPauser

```solidity
error AlreadyPauser();
```

### NotPauser

```solidity
error NotPauser();
```

### OnlyPauser

```solidity
error OnlyPauser();
```

