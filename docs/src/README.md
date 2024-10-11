## arrakis-modular

### install deps

```bash
forge install
```

### compile contracts

```bash
forge compile
```

### fill in env vars

```bash
cp .envExample .env
```

NOTE: you must add your own alchemy api key to `ETH_RPC_URL`

### test

```bash
forge test -vv
```
### Addresses

| Name                                           | Address                                       |
|------------------------------------------------|-----------------------------------------------|
| ArrakisStandardManager                         | 0x2e6E879648293e939aA68bA4c6c129A1Be733bDA |
| ArrakisTimeLock                                | 0xAf6f9640092cB1236E5DB6E517576355b6C40b7f |
| Factory                                        | 0x820FB8127a689327C863de8433278d6181123982 |
| PrivateVaultNFT                                | 0x44A801e7E2E073bd8bcE4bCCf653239Fa156B762 |
| Renderer Controller                            | 0x1Cc0Adff599F244f036a5C2425f646Aef884149D |
| Guardian                                       | 0x6F441151B478E0d60588f221f1A35BcC3f7aB981 |
| Public Registry                                 | 0x791d75F87a701C3F7dFfcEC1B6094dB22c779603 |
| Private Registry                                | 0xe278C1944BA3321C1079aBF94961E9fF1127A265 |
| Router                                         | 0x72aa2C8e6B14F30131081401Fa999fC964A66041 |
| RouterExecutor                                  | 0x19488620Cdf3Ff1B0784AC4529Fb5c5AbAceb1B6 |
| Router Resolver                                 | 0xC6c53369c36D6b4f4A6c195441Fe2d33149FB265 |
| Valantis Public Module Implementation           | 0x9Ac1249E37EE1bDc38dC0fF873F1dB0c5E6aDdE3 |
| Valantis Private Module Implementation          | 0x7E2fc9b2D37EA3E771b6F2375915b87CcA9E55bc |

NOTE : deployed on mainnet, arbitrum, base and sepolia.
