# IPermit2
[Git Source](https://github.com/ArrakisFinance/arrakis-modular/blob/main/src/interfaces/IPermit2.sol)


## Functions
### permitTransferFrom


```solidity
function permitTransferFrom(
    PermitBatchTransferFrom memory permit,
    SignatureTransferDetails[] calldata transferDetails,
    address owner,
    bytes calldata signature
) external;
```

### permitTransferFrom


```solidity
function permitTransferFrom(
    PermitTransferFrom memory permit,
    SignatureTransferDetails calldata transferDetails,
    address owner,
    bytes calldata signature
) external;
```

