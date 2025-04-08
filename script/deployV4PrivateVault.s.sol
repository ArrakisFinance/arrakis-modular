// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {console} from "forge-std/console.sol";
import {CreateXScript} from "./deployment/CreateXScript.sol";

import {IPoolManager} from
    "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {
    PoolKey, Currency
} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {CurrencyLibrary} from
    "@uniswap/v4-core/src/types/Currency.sol";
import {
    PoolId,
    PoolIdLibrary
} from "@uniswap/v4-core/src/types/PoolId.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";

import {
    NATIVE_COIN, TEN_PERCENT
} from "../src/constants/CArrakis.sol";
import {UniV4Oracle} from "../src/oracles/UniV4Oracle.sol";
import {IOracleWrapper} from "../src/interfaces/IOracleWrapper.sol";
import {IUniV4StandardModule} from
    "../src/interfaces/IUniV4StandardModule.sol";
import {IArrakisMetaVaultFactory} from
    "../src/interfaces/IArrakisMetaVaultFactory.sol";
import {IArrakisMetaVault} from
    "../src/interfaces/IArrakisMetaVault.sol";
import {IBunkerModule} from "../src/interfaces/IBunkerModule.sol";

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

// IMPORTANT !!! Fill in / check these sensitive varaibles before running script !!!

// #region enums.

enum OracleDeployment {
    UniV4Oracle,
    ChainlinkOracleWrapper,
    DeployedChainlinkOracleWrapper
}

// #endregion enums.

address constant token0 = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
address constant token1 = NATIVE_COIN;
uint24 constant fee = 500;
int24 constant tickSpacing = 10;
address constant hooks = address(0);
uint160 constant sqrtPrice = 33965778792757789688229654398626;

bool constant isInversed = true;

bytes32 constant salt =
    keccak256(abi.encode("BASE ETH/USDC Uni V4 private vault beta 2"));
address constant vaultOwner =
    0x81a1e7F34b9bABf172087cF5df8A4DF6500e9d4d;
uint24 constant maxSlippage = TEN_PERCENT / 2;

uint24 constant maxDeviation = TEN_PERCENT;
uint256 constant cooldownPeriod = 60;
address constant executor = 0x81a1e7F34b9bABf172087cF5df8A4DF6500e9d4d;
address constant stratAnnouncer =
    0x81a1e7F34b9bABf172087cF5df8A4DF6500e9d4d;

address constant factory = 0x820FB8127a689327C863de8433278d6181123982;
address constant nft = 0x44A801e7E2E073bd8bcE4bCCf653239Fa156B762;

OracleDeployment constant oracleDeployment =
    OracleDeployment.UniV4Oracle;

bool constant createPool = false;

// #region chainlink oracle wrapper.

bytes constant creationCode_chainlinkOracleWrapper =
    hex"6101206040523480156200001257600080fd5b506040516200128c3803806200128c833981016040819052620000359162000132565b6200004033620000b3565b6001600160a01b038416620000805760405162461bcd60e51b81526020600482015260026024820152615a4160f01b604482015260640160405180910390fd5b60ff9586166080529390941660a0526001600160a01b0391821660c0521660e052600191909155151561010052620001b2565b600080546001600160a01b038381166001600160a01b0319831681178455604051919092169283917f8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e09190a35050565b805160ff811681146200011557600080fd5b919050565b80516001600160a01b03811681146200011557600080fd5b60008060008060008060c087890312156200014c57600080fd5b620001578762000103565b9550620001676020880162000103565b945062000177604088016200011a565b935062000187606088016200011a565b92506080870151915060a08701518015158114620001a457600080fd5b809150509295509295509295565b60805160a05160c05160e051610100516110426200024a600039600081816104b5015261080801526000818161019c015281816102330152818161058b0152610ab10152600081816101320152818161027701528181610424015281816105cf015261077701526000818160d30152818161084d01526108840152600081816101cb015281816104f9015261055601526110426000f3fe608060405234801561001057600080fd5b50600436106100c95760003560e01c8063a726470511610081578063e84b8fe51161005b578063e84b8fe5146101ed578063ed6308f7146101f5578063f2fde38b1461020857600080fd5b8063a726470514610197578063a941ada9146101be578063b31ac6e2146101c657600080fd5b8063715018a6116100b2578063715018a614610123578063741bef1a1461012d5780638da5cb5b1461017957600080fd5b80630b77884d146100ce5780633cccb49c1461010c575b600080fd5b6100f57f000000000000000000000000000000000000000000000000000000000000000081565b60405160ff90911681526020015b60405180910390f35b61011560015481565b604051908152602001610103565b61012b61021b565b005b6101547f000000000000000000000000000000000000000000000000000000000000000081565b60405173ffffffffffffffffffffffffffffffffffffffff9091168152602001610103565b60005473ffffffffffffffffffffffffffffffffffffffff16610154565b6101547f000000000000000000000000000000000000000000000000000000000000000081565b61011561022f565b6100f57f000000000000000000000000000000000000000000000000000000000000000081565b610115610587565b61012b610203366004610d8f565b6108aa565b61012b610216366004610da8565b6108ff565b6102236109b6565b61022d6000610a37565b565b60007f000000000000000000000000000000000000000000000000000000000000000073ffffffffffffffffffffffffffffffffffffffff161561027557610275610aac565b7f000000000000000000000000000000000000000000000000000000000000000073ffffffffffffffffffffffffffffffffffffffff1663feaf968c6040518163ffffffff1660e01b815260040160a060405180830381865afa92505050801561031a575060408051601f3d9081017fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe016820190925261031791810190610dfd565b60015b6103ab576040517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820152602860248201527f436861696e4c696e6b4f7261636c653a20707269636520666565642063616c6c60448201527f206661696c65642e00000000000000000000000000000000000000000000000060648201526084015b60405180910390fd5b6001546103b88342610e7c565b1115610420576040517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820152601a60248201527f436861696e4c696e6b4f7261636c653a206f757464617465642e00000000000060448201526064016103a2565b60007f000000000000000000000000000000000000000000000000000000000000000073ffffffffffffffffffffffffffffffffffffffff1663313ce5676040518163ffffffff1660e01b8152600401602060405180830381865afa15801561048d573d6000803e3d6000fd5b505050506040513d601f19601f820116820180604052508101906104b19190610e93565b90507f00000000000000000000000000000000000000000000000000000000000000006105455761053a61052d6104e9836002610eb6565b6104f490600a610ffd565b61051f7f0000000000000000000000000000000000000000000000000000000000000000600a610ffd565b61052889610c4d565b610cbd565b600161052884600a610ffd565b965050505050505090565b61053a61055186610c4d565b61057c7f0000000000000000000000000000000000000000000000000000000000000000600a610ffd565b61052884600a610ffd565b60007f000000000000000000000000000000000000000000000000000000000000000073ffffffffffffffffffffffffffffffffffffffff16156105cd576105cd610aac565b7f000000000000000000000000000000000000000000000000000000000000000073ffffffffffffffffffffffffffffffffffffffff1663feaf968c6040518163ffffffff1660e01b815260040160a060405180830381865afa925050508015610672575060408051601f3d9081017fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe016820190925261066f91810190610dfd565b60015b6106fe576040517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820152602860248201527f436861696e4c696e6b4f7261636c653a20707269636520666565642063616c6c60448201527f206661696c65642e00000000000000000000000000000000000000000000000060648201526084016103a2565b60015461070b8342610e7c565b1115610773576040517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820152601a60248201527f436861696e4c696e6b4f7261636c653a206f757464617465642e00000000000060448201526064016103a2565b60007f000000000000000000000000000000000000000000000000000000000000000073ffffffffffffffffffffffffffffffffffffffff1663313ce5676040518163ffffffff1660e01b8152600401602060405180830381865afa1580156107e0573d6000803e3d6000fd5b505050506040513d601f19601f820116820180604052508101906108049190610e93565b90507f0000000000000000000000000000000000000000000000000000000000000000156108735761053a61052d61083d836002610eb6565b61084890600a610ffd565b61051f7f0000000000000000000000000000000000000000000000000000000000000000600a610ffd565b61053a61087f86610c4d565b61057c7f0000000000000000000000000000000000000000000000000000000000000000600a610ffd565b6108b26109b6565b600180549082905560408051308152602081018390529081018390527f4be25d0984bef9e8c2ab124bd255b2fd9a7904b5c81e079a73ef7586b34a36ca9060600160405180910390a15050565b6109076109b6565b73ffffffffffffffffffffffffffffffffffffffff81166109aa576040517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820152602660248201527f4f776e61626c653a206e6577206f776e657220697320746865207a65726f206160448201527f646472657373000000000000000000000000000000000000000000000000000060648201526084016103a2565b6109b381610a37565b50565b60005473ffffffffffffffffffffffffffffffffffffffff16331461022d576040517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820181905260248201527f4f776e61626c653a2063616c6c6572206973206e6f7420746865206f776e657260448201526064016103a2565b6000805473ffffffffffffffffffffffffffffffffffffffff8381167fffffffffffffffffffffffff0000000000000000000000000000000000000000831681178455604051919092169283917f8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e09190a35050565b6000807f000000000000000000000000000000000000000000000000000000000000000073ffffffffffffffffffffffffffffffffffffffff1663feaf968c6040518163ffffffff1660e01b815260040160a060405180830381865afa158015610b1a573d6000803e3d6000fd5b505050506040513d601f19601f82011682018060405250810190610b3e9190610dfd565b5050925092505081600014610baf576040517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820152601f60248201527f436861696e4c696e6b4f7261636c653a2073657175656e63657220646f776e0060448201526064016103a2565b610e10610bbc8242610e7c565b11610c49576040517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820152602660248201527f436861696e4c696e6b4f7261636c653a20677261636520706572696f64206e6f60448201527f74206f766572000000000000000000000000000000000000000000000000000060648201526084016103a2565b5050565b600080821215610cb9576040517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820181905260248201527f53616665436173743a2076616c7565206d75737420626520706f73697469766560448201526064016103a2565b5090565b600080807fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff85870985870292508281108382030391505080600003610d145760008411610d0957600080fd5b508290049050610d88565b808411610d2057600080fd5b600084868809851960019081018716968790049682860381900495909211909303600082900391909104909201919091029190911760038402600290811880860282030280860282030280860282030280860282030280860282030280860290910302029150505b9392505050565b600060208284031215610da157600080fd5b5035919050565b600060208284031215610dba57600080fd5b813573ffffffffffffffffffffffffffffffffffffffff81168114610d8857600080fd5b805169ffffffffffffffffffff81168114610df857600080fd5b919050565b600080600080600060a08688031215610e1557600080fd5b610e1e86610dde565b9450602086015193506040860151925060608601519150610e4160808701610dde565b90509295509295909350565b7f4e487b7100000000000000000000000000000000000000000000000000000000600052601160045260246000fd5b600082821015610e8e57610e8e610e4d565b500390565b600060208284031215610ea557600080fd5b815160ff81168114610d8857600080fd5b600060ff821660ff84168160ff0481118215151615610ed757610ed7610e4d565b029392505050565b600181815b80851115610f3857817fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff04821115610f1e57610f1e610e4d565b80851615610f2b57918102915b93841c9390800290610ee4565b509250929050565b600082610f4f57506001610ff7565b81610f5c57506000610ff7565b8160018114610f725760028114610f7c57610f98565b6001915050610ff7565b60ff841115610f8d57610f8d610e4d565b50506001821b610ff7565b5060208310610133831016604e8410600b8410161715610fbb575081810a610ff7565b610fc58383610edf565b807fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff04821115610ed757610ed7610e4d565b92915050565b6000610d8860ff841683610f4056fea26469706673582212205aa8244867135c60c85382684fca646f2d27ed11085b3f98deb50f69e21ac8b564736f6c634300080d0033";

uint8 constant token0Decimals = 18;
uint8 constant token1Decimals = 18;
address constant priceFeed = address(0);
address constant sequencerUpTimeFeed = address(0);
uint256 constant outdated = 0;
bool constant isPriceFeedInversed = false;

// #endregion chainlink oracle wrapper.

address constant chainlinkOracleWrapper = address(0);

bool constant sendOwnershipToSafe = false;
address constant safe = address(0);

contract DeployV4PrivateVault is CreateXScript {
    using PoolIdLibrary for PoolKey;

    function setUp() public {}

    function run() public {
        address poolManager = getPoolManager();

        address uniV4PrivateUpgradeableBeacon = getUpgradeableBeacon();

        vm.startBroadcast();

        console.log("Deployer : ");
        console.logAddress(msg.sender);

        // #region create uni v4 pool.

        PoolKey memory poolKey;

        if (isInversed) {
            poolKey = PoolKey({
                currency0: CurrencyLibrary.ADDRESS_ZERO,
                currency1: Currency.wrap(token0),
                fee: fee,
                tickSpacing: tickSpacing,
                hooks: IHooks(hooks)
            });
        } else {
            poolKey = PoolKey({
                currency0: CurrencyLibrary.ADDRESS_ZERO,
                currency1: Currency.wrap(token1),
                fee: fee,
                tickSpacing: tickSpacing,
                hooks: IHooks(hooks)
            });
        }

        if (createPool) {
            IPoolManager(poolManager).initialize(poolKey, sqrtPrice);
        }

        PoolId poolId = poolKey.toId();

        console.log("Pool Id : ");
        console.logBytes32(PoolId.unwrap(poolId));

        // #endregion create uni v4 pool.

        // #region create uni V4 oracle.

        address oracle;

        if (oracleDeployment == OracleDeployment.UniV4Oracle) {
            oracle = address(new UniV4Oracle(poolManager, isInversed));

            console.log("Uni V4 Oracle : ");
            console.logAddress(oracle);
        }
        if (
            oracleDeployment
                == OracleDeployment.ChainlinkOracleWrapper
        ) {
            bytes memory initCode = abi.encodePacked(
                creationCode_chainlinkOracleWrapper,
                abi.encode(
                    token0Decimals,
                    token1Decimals,
                    priceFeed,
                    sequencerUpTimeFeed,
                    outdated,
                    isPriceFeedInversed
                )
            );

            oracle = CreateX.deployCreate(initCode);

            console.log("Chainlink Oracle Wrapper : ");
            console.logAddress(oracle);
        }
        if (
            oracleDeployment
                == OracleDeployment.DeployedChainlinkOracleWrapper
        ) {
            oracle = chainlinkOracleWrapper;

            console.log("Deployed Chainlink Oracle Wrapper : ");
            console.logAddress(oracle);
        }

        // #endregion create uni V4 oracle.

        // #region create private vault.

        bytes memory moduleCreationPayload = abi.encodeWithSelector(
            IUniV4StandardModule.initialize.selector,
            1, // not important for private vault.
            1, // not important for private vault.
            isInversed,
            poolKey,
            IOracleWrapper(oracle),
            maxSlippage
        );
        bytes memory initManagementPayload = abi.encode(
            IOracleWrapper(oracle),
            maxDeviation,
            cooldownPeriod,
            executor,
            stratAnnouncer,
            maxSlippage
        );

        address vault = IArrakisMetaVaultFactory(factory)
            .deployPrivateVault(
            salt,
            token0,
            token1,
            vaultOwner,
            uniV4PrivateUpgradeableBeacon,
            moduleCreationPayload,
            initManagementPayload
        );

        console.logString("Uniswap Private Vault Address : ");
        console.logAddress(vault);

        // #endregion create private vault.

        // #region initialize oracle.

        // do it manually after.


        // #endregion initialize oracle.

        // #region whitelist bunker module.

        if (vaultOwner == msg.sender) {
            address[] memory beacons = new address[](1);
            beacons[0] = getBunkerModule();

            bytes[] memory payloads = new bytes[](1);
            payloads[0] = abi.encodeWithSelector(
                IBunkerModule.initialize.selector, vault
            );

            IArrakisMetaVault(vault).whitelistModules(
                beacons, payloads
            );
        }

        // #endregion whitelist bunker module.

        // #region send ownership to safe.

        if (sendOwnershipToSafe) {
            ERC721(nft).approve(safe, uint256(uint160(vault)));
            ERC721(nft).safeTransferFrom(
                msg.sender, safe, uint256(uint160(vault))
            );
        }

        // #endregion send ownership to safe.

        vm.stopBroadcast();
    }

    function getUpgradeableBeacon() internal view returns (address) {
        uint256 chainId = block.chainid;

        // mainnet
        if (chainId == 1) {
            return 0x022a0C7dc85Fc3fF81f9f8Ef65Ae2813A062F556;
        }
        // polygon
        else if (chainId == 137) {
            return 0xFb4e25800b77BcD09227729FFCC145685797f408;
        }
        // optimism
        else if (chainId == 10) {
            return 0x413fc8E6F0B95D1f45de01b17e9441ec41eD01AB;
        }
        // sepolia
        else if (chainId == 11_155_111) {
            return 0xC0b7FaC163566A768B4F30d06fD4b08bb6b987F0;
        }
        // base
        else if (chainId == 8453) {
            return 0x97d42db1B71B1c9a811a73ce3505Ac00f9f6e5fB;
        }
        // Ink
        else if (chainId == 57_073) {
            return 0xCc8989978668ad377369C0cC720192377a6006e3;
        }
        // Unichain
        else if (chainId == 130) {
            return 0xCc8989978668ad377369C0cC720192377a6006e3;
        }
        // Arbitrum
        else if (chainId == 42_161) {
            return 0xe1a76410dfB11d6C60a43838FA853519f13dEef4;
        }
        // default
        else {
            revert("Not supported network!");
        }
    }

    function getBunkerModule() internal view returns (address) {
        uint256 chainId = block.chainid;

        // mainnet
        if (chainId == 1) {
            return 0xFf0474792DEe71935a0CeF1306D93fC1DCF47BD9;
        }
        // polygon
        else if (chainId == 137) {
            return 0xD4ae05C8928d4850cDD0f800322108E6B1a8F3eB;
        }
        // optimism
        else if (chainId == 10) {
            return 0x79FC92aFa1Ce5476010644380156790d2fC52168;
        }
        // sepolia
        else if (chainId == 11_155_111) {
            return 0xB4dA34605c26BA152d465DeB885889070105BB5F;
        }
        // base
        else if (chainId == 8453) {
            return 0x3025b46A9814a69EAf8699EDf905784Ee22C3ABB;
        }
        // Ink
        else if (chainId == 57_073) {
            return 0x4B6FEE838b3dADd5f0846a9f2d74081de96e6f73;
        }
        // Unichain
        else if (chainId == 130) {
            return 0x4B6FEE838b3dADd5f0846a9f2d74081de96e6f73;
        }
        // Arbitrum
        else if (chainId == 42_161) {
            return 0xe25F763fa58de798AF2e454e916F527cdD17E885;
        }
        // default
        else {
            revert("Not supported network!");
        }
    }

    function getPoolManager() public view returns (address) {
        uint256 chainId = block.chainid;

        // mainnet
        if (chainId == 1) {
            return 0x000000000004444c5dc75cB358380D2e3dE08A90;
        }
        // polygon
        else if (chainId == 137) {
            return 0x67366782805870060151383F4BbFF9daB53e5cD6;
        }
        // optimism
        else if (chainId == 10) {
            return 0x9a13F98Cb987694C9F086b1F5eB990EeA8264Ec3;
        }
        // sepolia
        else if (chainId == 11_155_111) {
            return 0xE03A1074c86CFeDd5C142C4F04F1a1536e203543;
        }
        // base
        else if (chainId == 8453) {
            return 0x498581fF718922c3f8e6A244956aF099B2652b2b;
        }
        // Ink
        else if (chainId == 57_073) {
            return 0x360E68faCcca8cA495c1B759Fd9EEe466db9FB32;
        }
        // Unichain
        else if (chainId == 130) {
            return 0x1F98400000000000000000000000000000000004;
        }
        // Arbitrum
        else if (chainId == 42_161) {
            return 0x360E68faCcca8cA495c1B759Fd9EEe466db9FB32;
        }
        // default
        else {
            revert("Not supported network!");
        }
    }
}
