# ISovereignPool
[Git Source](https://github.com/ArrakisFinance/arrakis-modular/blob/4485c572ded3a830c181fa38ceaac13efe8eb7f1/src/interfaces/ISovereignPool.sol)


## Functions
### setPoolManagerFeeBips


```solidity
function setPoolManagerFeeBips(uint256 poolManagerFeeBips_)
    external;
```

### setPoolManager


```solidity
function setPoolManager(address manager_) external;
```

### claimPoolManagerFees


```solidity
function claimPoolManagerFees(
    uint256 feeProtocol0Bips_,
    uint256 feeProtocol1Bips_
)
    external
    returns (
        uint256 feePoolManager0Received,
        uint256 feePoolManager1Received
    );
```

### getPoolManagerFees


```solidity
function getPoolManagerFees()
    external
    view
    returns (uint256 poolManagerFee0, uint256 poolManagerFee1);
```

### poolManagerFeeBips


```solidity
function poolManagerFeeBips() external view returns (uint256);
```

### getReserves


```solidity
function getReserves() external view returns (uint256, uint256);
```

