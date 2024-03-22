# Arrakis Modular

## Motivation: 

Arrakis Modular represents the next evolution of Arrakis Finance's liquidity management, aiming to overcome the limitations of previous versions (V1 and V2). Traditionally, our LP vaults allowed Liquidity Providers (LPs) to actively manage or delegate the management of their (DEX) liquidity positions. LPs could invest in shared liquidity provision strategies by holding an ERC20 token representing a share of the underlying strategy. However, Arrakis V1 and V2 were specifically built around Uniswap V3. Therefore, the previous standards were incompatible with other DEXs, and in order to support alternative venues —like Uniswap V4, Balancer, Ambient, etc.— Arrakis would have to make a completely new standard for every integration.

To address this, Arrakis Modular introduces a universal Meta-Vault standard. This modular framework enables the attachment of standardized modules to any two-sided liquidity provision protocol, simplifying the integration process. Key features include:
- **Flexibility**: Modules adhering to a common interface can be easily developed and attached, supporting a broad range of DEXs.
- **Reusability**: The Arrakis Vault standard facilitates the reuse of components and maintenance of standard interfaces, streamlining future expansions.
- **Scalability**: Adapting to new liquidity pool types becomes straightforward, focusing on module development rather than protocol overhauls.

We envision Arrakis Modular not only as a technical advancement but as a platform for community and developer collaboration, inviting contributions to the ecosystem. With this modular approach, Arrakis Finance is poised to rapidly adapt to the evolving DeFi landscape, unlocking new possibilities for liquidity management.
 
Finally, note that the potential for modules extends beyond single DEX integrations. While current use cases focus on individual DEX liquidity provision protocols, in theory, modules could become more complex, enabling integrations with multiple DEXs simultaneously or combining DEX and peripheral protocols like lending markets or options protocols (hedging and delta-neutral strategies could become a reality one day). Although these advanced functionalities are out of scope for now, the architecture of Arrakis Modular supports such future innovations.

## Background

As Arrakis Modular builds upon the learnings from Arrakis V2, a basic understanding of the legacy system is beneficial for comprehending the enhancements introduced in this new version. Arrakis V2 was structured around three main repositories:
- [v2-core](https://github.com/ArrakisFinance/v2-core): This repository contains the core components of the system, such as vault logic, its factories, and math helpers.
- [v2-periphery](https://github.com/ArrakisFinance/v2-periphery): This one includes key elements that integrate with the core components, featuring a router for ease of user deposits/withdrawals, and a gauge system to incentivize vaults with rewards.
- [v2-manager-templates](https://github.com/ArrakisFinance/v2-manager-templates): For vaults managed by third parties, Arrakis V2 introduced smart contract managers to limit their powers and provide guarantees to users, with several managers offering different functionalities and trust assumptions.

After the market signaled the desire for private vaults managed by a third-party, Arrakis PALM (Protocol Automated Liquidity Management) was built on top of the Arrakis V2 system:
- [v2-palm](https://github.com/ArrakisFinance/v2-palm): Solution for private liquidity management operated by a third-party. Introduces a new type of manager tailored to the needs of the product.

> Note that all repositories listed above contain links to their respective audits.

Drawing on over two years of insights and learnings from operating a liquidity management system, Arrakis Modular adopts a more opinionated design approach. This approach aims to streamline the system by reducing the complexity inherited from having three different, independent smart contract layers. To achieve this, all components are combined within a single monorepo, enhancing collaboration, simplifying maintenance, and aligning with the modular design principles of Arrakis Modular. This consolidation reflects our commitment to improving developer experience and system coherence, paving the way for more efficient and flexible liquidity management solutions.

# System Design

At the heart of the Arrakis Modular system is the concept of meta-vaults. These meta-vaults enable users wishing to provide liquidity with two distinct assets to do so across any trading venue—without the need to deploy or migrate funds to new vaults. Meta-vaults have the capability to whitelist various modules, essentially smart contracts that establish integration with liquidity-consuming dApps. This design ensures that as new DEXs emerge, liquidity provision becomes a matter of simply creating and whitelisting a new module compatible with the DEX, and then activating it.

Arrakis Modular strategically differentiates between public and private vaults, offering tailored solutions for both. Each type of vault is supported by a corresponding module registry—one for public meta-vaults and another for private ones. These registries manage whitelisted module beacons, which offer the assurance of being non-upgradable or only upgradable under the strict governance of the Arrakis Timelock.

The Meta-Vault Factory is in charge of creating new meta-vaults —both public and private—. During the initial creation of a meta-vault, the factory also generates a new beacon contract for the chosen module from the relevant module registry, ensuring that all modules adhere to registry standards and uphold strict upgradability policies.

Moreover, Arrakis Modular high standards of security and trust in regards of fund management. The Arrakis Standard Manager—a singular contract with the authority to manage liquidity across all meta-vaults—, provides users with assurances against malpractices by the strategy manager, such as misappropriation of funds or executing high-slippage swaps/rebalances.

Lastly, the inclusion of a public vault router simplifies the user experience. It allows users to effortlessly deposit their tokens, including ETH, through mechanisms like token approvals or permit2, abstracting the complexity of MEV-protected swaps and offering a streamlined liquidity provision process.

![arrakis-modular-diagram](./arrakis-modular-diagram.png)

---

Table of Contents:

abstracts/ArrakisMetaVault.sol
abstracts/ModuleRegistry.sol
modules/ValantisSOTModule.sol
ArrakisMetaVaultPublic.sol
ArrakisMetaVaultPrivate.sol
ArrakisMetaVaultFactory.sol
PALMVaultNFT.sol
Guardian.sol
ModulePrivateRegistry.sol
ModulePublicRegistry.sol
ArrakisStandardManager.sol
ArrakisPublicVaultRouter.sol
RouterSwapExecutor.sol
TimeLock.sol

abstracts/ArrakisMetaVault.sol This contract is the core of the minimal Arrakis Meta Vault standard. It encodes the interfaces and patterns of an Arrakis Meta Vault. A functional ArrakisMetaVault has a module contract connected to it which entirely defines how the vault integrates with an underlying Liquidity Provision protocol, using standard interfaces. This contract is abstract because it is extended to expose the differenced in the Public and Private vault type, most notable how they are tokenized and how the deposit function is implemented.

ArrakisMetaVaultPublic.sol This inherits and extends the abstract ArrakisMetaVault.sol to create the ERC20 wrapped “public” Arrakis Meta Vault. If we want to create a shared LP position/strategy which can configure or delegate LP active management on behalf of all participants, then we’ll deploy an instance of this through the Factory contract. Public Vault deployments are permissioned since sensitive security parameters for multiple parties are under the timelocked control of a vault owner, so we want some ability to control who might deploy/configure/own these public vaults. Eventually this authority would be under the control of the “Arrakis DAO.”

ArrakisMetaVaultPrivate.sol This inherits and extends the abstract ArrakisMetaVault.sol to create the “private” Arrakis Meta Vault, where only the vault owner controls adding or removing liquidity. If you want to create an LP management contract for your own private liquidity (we call this PALM for private active liquidity management) you’d deploy an instance of this through the Factory contract. Ownership is not timelocked and deployment is permissionless in this case, since the sensitive security parameters are fundamentally under the control of the custodian of the vault funds (i.e. the owner is the user).

PALMVaultNFT.sol an NFT contract that allows ownership of private vaults to each be tokenized and thus transferrable. Very standard NFT contract (we might add some fun visuals to the tokenURI but this has no effect on contract security AFAIU)

ArrakisMetaVaultFactory.sol deploys fresh instances of ArrakisMetaVaultPublic and ArrakisMetaVaultPrivate public vault deployments are permissioned, but private vault ones are not. Stores complete list of all vaults deployed, by type.

ArrakisStandardManager.sol The manager contract that adds additional safety checks to make delegated LP management safe and as trustless as possible. Arrakis will use this as the entry point to actively manage both private vaults and public vaults. Also how we confiuge/harvest manager fee collection for Arrakis protocol to take cut of revenues generated.

ArrakisPublicVaultRouter.sol A router contract which integrates permit2 which helps depositors add liquidity to ArrakisMetaVaultPublic instances, safely and conveniently.

RouterSwapExecutor.sol a sub-component of the Public Vault Router used for swapping safely (need the middleman contract here for security concerns on these generic low level swaps being abused)

modules/ValantisSOTModule.sol This is the first ArrakisMetaVault module we will put into production, integrating a specific Sovereign Pool type of the new Valantis DEX.

TimeLock.sol a slightly modified generic timelock (so that timelock cannot transfer ownership of the vault away from the timelock contract) a fresh instance of this is used for each Public Arrakis vault to make sure that security parameters cannot be rushingly reconfigured by a compromised public vault owner to extract value from the public vault.

abstract/ModuleRegistry.sol this abstract contract handles the simple duty of “module” whitelistsing, so only modules deemed safe and correct can be used by vaults.

ModulePrivateRegistry.sol registry of all modules which can be whitelisted and used by private vaults.

ModulePublicRegsitry.sol registry of all modules which can be whitelisted and used by public vaults.

Guardian.sol this contract is in charge of a rushing pauser role who can pause parts of the system in the case of critical error/vulnerability. This authority would be ultimately in the hands of some “Guardian Multisig” much like how AAVE works today. For any upgradeable contracts (modules are all beacon proxies and could potentially be upgradeable) there would be a timelock. So pauses are rushing but upgrades are slow.