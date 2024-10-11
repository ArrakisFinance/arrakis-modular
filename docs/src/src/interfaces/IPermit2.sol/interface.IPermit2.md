# IPermit2
[Git Source](https://github.com/ArrakisFinance/arrakis-modular/blob/4485c572ded3a830c181fa38ceaac13efe8eb7f1/src/interfaces/IPermit2.sol)


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

