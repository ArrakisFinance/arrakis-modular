// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

// #region foundry.
import {console} from "forge-std/console.sol";
import {TestWrapper} from "../../utils/TestWrapper.sol";
// #endregion foundry.

// #region
import {UniV4BlockBuilder} from
    "../../../src/modules/UniV4BlockBuilder.sol";
import {BuilderHook} from "../../../src/hooks/BuilderHook.sol";
import {IUniV4StandardModule} from
    "../../../src/interfaces/IUniV4StandardModule.sol";
import {IBuilderHook} from "../../../src/interfaces/IBuilderHook.sol";
import {IPermissionHook} from
    "../../../src/interfaces/IPermissionHook.sol";
import {PIPS} from "../../../src/constants/CArrakis.sol";
import {IOwnable} from "../../../src/interfaces/IOwnable.sol";
import {Deal} from "../../../src/structs/SBuilder.sol";
import {DEAL_EIP712HASH} from "../../../src/constants/CBuilder.sol";
import {BuilderDeal} from "../../../src/libraries/BuilderDeal.sol";
// #endregion

// #region uniswap v4.
import {IPoolManager} from
    "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolManager} from "@uniswap/v4-core/src/PoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {
    Currency,
    CurrencyLibrary
} from "@uniswap/v4-core/src/types/Currency.sol";
import {StateLibrary} from
    "@uniswap/v4-core/src/libraries/StateLibrary.sol";
import {TransientStateLibrary} from
    "@uniswap/v4-core/src/libraries/TransientStateLibrary.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {LiquidityAmounts} from
    "@uniswap/v4-periphery/contracts/libraries/LiquidityAmounts.sol";
import {
    PoolIdLibrary,
    PoolId
} from "@uniswap/v4-core/src/types/PoolId.sol";
// #endregion uniswap v4.

import {SignatureChecker} from
    "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// #region mock contracts.

import {GuardianMock} from "./mocks/Guardian.sol";
import {ArrakisMetaVaultMock} from "./mocks/ArrakisMetaVault.sol";

// #endregion mock contracts.

contract BuilderHookTest is TestWrapper {
    using StateLibrary for IPoolManager;
    using TransientStateLibrary for IPoolManager;
    using PoolIdLibrary for PoolKey;
    using BuilderDeal for Deal;
    using SignatureChecker for address;

    // #region constants.
    address public constant USDC =
        0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant WETH =
        0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    // #endregion constants.

    PoolManager public poolManager;
    PoolKey public poolKey;
    uint160 public sqrtPriceX96;
    address public manager;
    address public pauser;
    address public metaVault;
    address public guardian;
    address public owner;
    uint256 public signer;
    address public signerAddr;

    UniV4BlockBuilder public module;
    BuilderHook public hook;

    function setUp() public {
        manager = vm.addr(uint256(keccak256(abi.encode("Manager"))));
        pauser = vm.addr(uint256(keccak256(abi.encode("Pauser"))));
        owner = vm.addr(uint256(keccak256(abi.encode("Owner"))));
        signer = uint256(keccak256(abi.encode("Signer")));
        signerAddr = vm.addr(signer);

        // #region meta vault creation.

        metaVault = address(new ArrakisMetaVaultMock(manager, owner));

        // #endregion meta vault creation.
        // #region create a guardian.

        guardian = address(new GuardianMock(pauser));

        // #endregion create a guardian.
        // #region do a poolManager deployment.

        poolManager = new PoolManager(0);

        // #endregion do a poolManager deployment.

        // #region create a uni V4 standard module.
        uint256 init0 = 3000e6;
        uint256 init1 = 1e18;

        module = new UniV4BlockBuilder(
            address(poolManager),
            metaVault,
            USDC,
            WETH,
            init0,
            init1,
            guardian,
            false
        );
        // #endregion create a uni V4 standard module.

        // #region create a permission hook.

        hook = BuilderHook(
            address(
                uint160(
                    Hooks.BEFORE_ADD_LIQUIDITY_FLAG
                        | Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG
                        | Hooks.AFTER_INITIALIZE_FLAG
                        | Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG
                )
            )
        );

        uint24 fee = 10_000;

        BuilderHook implementation = new BuilderHook(
            address(module), signerAddr, address(poolManager), fee
        );

        vm.etch(address(hook), address(implementation).code);

        hook.initialize(owner);

        // #endregion create a permission hook.

        // #region create uniswap v4 pool.

        Currency currency0 = Currency.wrap(USDC);
        Currency currency1 = Currency.wrap(WETH);

        poolKey = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: fee,
            /// @dev 1% swap fee.
            tickSpacing: 10,
            hooks: IHooks(address(hook))
        });

        sqrtPriceX96 = 1_356_476_084_642_877_807_665_053_548_195_417;

        poolManager.unlock(abi.encode(2));

        // #endregion create uniswap v4 pool.

        vm.prank(IOwnable(address(metaVault)).owner());
        module.initializePoolKey(poolKey);
    }

    function unlockCallback(bytes calldata data)
        public
        returns (bytes memory)
    {
        uint256 typeOfLockAcquired = abi.decode(data, (uint256));

        if (typeOfLockAcquired == 2) {
            poolManager.initialize(poolKey, sqrtPriceX96, "");
        }
    }

    // #region test constructor.

    function testConstructorOwnerAddressZero() public {
        uint24 fee = 10_000;

        BuilderHook implementation = new BuilderHook(
            address(module), signerAddr, address(poolManager), fee
        );

        vm.expectRevert(IPermissionHook.AddressZero.selector);
        implementation.initialize(address(0));
    }

    function testConstructorSignerAddressZero() public {
        uint24 fee = 10_000;

        vm.expectRevert(IPermissionHook.AddressZero.selector);
        BuilderHook implementation = new BuilderHook(
            address(module), address(0), address(poolManager), fee
        );
    }

    function testConstructorPoolManagerAddressZero() public {
        uint24 fee = 10_000;

        vm.expectRevert(IPermissionHook.AddressZero.selector);
        BuilderHook implementation = new BuilderHook(
            address(module), signerAddr, address(0), fee
        );
    }

    function testConstructorFeeZero() public {
        uint24 fee = 0;

        vm.expectRevert(IBuilderHook.FeeZero.selector);
        BuilderHook implementation = new BuilderHook(
            address(module), signerAddr, address(poolManager), fee
        );
    }

    // #endregion test constructor.

    // #region test openPool.

    function testOpenPoolOnlyCaller() public {
        address caller =
            vm.addr(uint256(keccak256(abi.encode("Caller"))));
        address collateralToken = WETH;
        uint256 collateralAmount = 1 ether;
        address feeFreeSwapper = vm.addr(
            uint256(keccak256(abi.encode("Fee Free Swapper")))
        );
        uint256 feeGeneration0 = 0;
        uint256 feeGeneration1 = 0;
        uint160 finalSqrtPriceX96 = sqrtPriceX96;
        uint256 finalAmount0 = 0;
        uint256 finalAmount1 = 0;
        uint256 tips = 0;
        uint256 nonce = 1;
        uint256 blockHeight = block.number;

        // #region create a deal.

        Deal memory deal = Deal({
            caller: caller,
            collateralToken: collateralToken,
            collateralAmount: collateralAmount,
            feeFreeSwapper: feeFreeSwapper,
            feeGeneration0: feeGeneration0,
            feeGeneration1: feeGeneration1,
            finalSqrtPriceX96: finalSqrtPriceX96,
            finalAmount0: finalAmount0,
            finalAmount1: finalAmount1,
            tips: tips,
            nonce: nonce,
            blockHeight: blockHeight
        });

        // #endregion create a deal.

        // #region create a signature.

        bytes memory signature = getEOASignedDeal(deal, signer);

        // #endregion create a signature.

        vm.expectRevert(IBuilderHook.OnlyCaller.selector);
        hook.openPool(deal, signature);
    }

    function testOpenPoolCurrentBlock() public {
        address caller =
            vm.addr(uint256(keccak256(abi.encode("Caller"))));
        address collateralToken = WETH;
        uint256 collateralAmount = 1 ether;
        address feeFreeSwapper = vm.addr(
            uint256(keccak256(abi.encode("Fee Free Swapper")))
        );
        uint256 feeGeneration0 = 0;
        uint256 feeGeneration1 = 0;
        uint160 finalSqrtPriceX96 = sqrtPriceX96;
        uint256 finalAmount0 = 0;
        uint256 finalAmount1 = 0;
        uint256 tips = 0;
        uint256 nonce = 1;
        uint256 blockHeight = block.number - 1;

        // #region create a deal.

        Deal memory deal = Deal({
            caller: caller,
            collateralToken: collateralToken,
            collateralAmount: collateralAmount,
            feeFreeSwapper: feeFreeSwapper,
            feeGeneration0: feeGeneration0,
            feeGeneration1: feeGeneration1,
            finalSqrtPriceX96: finalSqrtPriceX96,
            finalAmount0: finalAmount0,
            finalAmount1: finalAmount1,
            tips: tips,
            nonce: nonce,
            blockHeight: blockHeight
        });

        // #endregion create a deal.

        // #region create a signature.

        bytes memory signature = getEOASignedDeal(deal, signer);

        // #endregion create a signature.

        vm.expectRevert(IBuilderHook.NotSameBlockHeight.selector);
        hook.openPool(deal, signature);
    }

    function testOpenPoolCannotReOpenThePool() public {
        address caller =
            vm.addr(uint256(keccak256(abi.encode("Caller"))));
        address collateralToken = WETH;
        uint256 collateralAmount = 1 ether;
        address feeFreeSwapper = vm.addr(
            uint256(keccak256(abi.encode("Fee Free Swapper")))
        );
        uint256 feeGeneration0 = 0;
        uint256 feeGeneration1 = 0;
        uint160 finalSqrtPriceX96 = sqrtPriceX96;
        uint256 finalAmount0 = 0;
        uint256 finalAmount1 = 0;
        uint256 tips = 0;
        uint256 nonce = 0;
        uint256 blockHeight = block.number;

        // #region create a deal.

        Deal memory deal = Deal({
            caller: caller,
            collateralToken: collateralToken,
            collateralAmount: collateralAmount,
            feeFreeSwapper: feeFreeSwapper,
            feeGeneration0: feeGeneration0,
            feeGeneration1: feeGeneration1,
            finalSqrtPriceX96: finalSqrtPriceX96,
            finalAmount0: finalAmount0,
            finalAmount1: finalAmount1,
            tips: tips,
            nonce: nonce,
            blockHeight: blockHeight
        });

        // #endregion create a deal.

        // #region create a signature.

        bytes memory signature = getEOASignedDeal(deal, signer);

        // #endregion create a signature.

        vm.expectRevert(IBuilderHook.CannotReOpenThePool.selector);
        vm.prank(caller);
        hook.openPool(deal, signature);
    }

    function testOpenPoolNotACollateral() public {
        address caller =
            vm.addr(uint256(keccak256(abi.encode("Caller"))));
        address collateralToken = WETH;
        uint256 collateralAmount = 1 ether;
        address feeFreeSwapper = vm.addr(
            uint256(keccak256(abi.encode("Fee Free Swapper")))
        );
        uint256 feeGeneration0 = 0;
        uint256 feeGeneration1 = 0;
        uint160 finalSqrtPriceX96 = sqrtPriceX96;
        uint256 finalAmount0 = 0;
        uint256 finalAmount1 = 0;
        uint256 tips = 0;
        uint256 nonce = 1;
        uint256 blockHeight = block.number;

        // #region create a deal.

        Deal memory deal = Deal({
            caller: caller,
            collateralToken: collateralToken,
            collateralAmount: collateralAmount,
            feeFreeSwapper: feeFreeSwapper,
            feeGeneration0: feeGeneration0,
            feeGeneration1: feeGeneration1,
            finalSqrtPriceX96: finalSqrtPriceX96,
            finalAmount0: finalAmount0,
            finalAmount1: finalAmount1,
            tips: tips,
            nonce: nonce,
            blockHeight: blockHeight
        });

        // #endregion create a deal.

        // #region create a signature.

        bytes memory signature = getEOASignedDeal(deal, signer);

        deal.finalSqrtPriceX96 = deal.finalSqrtPriceX96 + 1;

        // #endregion create a signature.

        vm.expectRevert(IBuilderHook.NotACollateral.selector);
        vm.prank(caller);
        hook.openPool(deal, signature);
    }

    function testOpenPoolNotValidSignature() public {
        Deal memory deal;
        address caller;

        {
            caller =
                vm.addr(uint256(keccak256(abi.encode("Caller"))));
            address collateralToken = WETH;
            uint256 collateralAmount = 1 ether;
            address feeFreeSwapper = vm.addr(
                uint256(keccak256(abi.encode("Fee Free Swapper")))
            );
            uint256 feeGeneration0 = 0;
            uint256 feeGeneration1 = 0;
            uint160 finalSqrtPriceX96 = sqrtPriceX96;
            uint256 finalAmount0 = 0;
            uint256 finalAmount1 = 0;
            uint256 tips = 0;
            uint256 nonce = 1;
            uint256 blockHeight = block.number;

            // #region create a deal.

            deal = Deal({
                caller: caller,
                collateralToken: collateralToken,
                collateralAmount: collateralAmount,
                feeFreeSwapper: feeFreeSwapper,
                feeGeneration0: feeGeneration0,
                feeGeneration1: feeGeneration1,
                finalSqrtPriceX96: finalSqrtPriceX96,
                finalAmount0: finalAmount0,
                finalAmount1: finalAmount1,
                tips: tips,
                nonce: nonce,
                blockHeight: blockHeight
            });

            // #endregion create a deal.
        }

        // #region whitelist collateral.

        address[] memory collaterals = new address[](1);
        collaterals[0] = WETH;

        vm.prank(owner);
        hook.whitelistCollaterals(collaterals);

        // #endregion whitelist collateral.

        // #region create a signature.

        bytes memory signature = getEOASignedDeal(deal, signer);

        deal.finalSqrtPriceX96 = deal.finalSqrtPriceX96 + 1;

        // #endregion create a signature.

        vm.expectRevert(IBuilderHook.NotValidSignature.selector);
        vm.prank(caller);
        hook.openPool(deal, signature);
    }

    function testOpenPool() public {
        Deal memory d;
        address caller;

        {
            caller =
                vm.addr(uint256(keccak256(abi.encode("Caller"))));
            address collateralToken = WETH;
            uint256 collateralAmount = 1 ether;
            address feeFreeSwapper = vm.addr(
                uint256(keccak256(abi.encode("Fee Free Swapper")))
            );
            uint256 feeGeneration0 = 0;
            uint256 feeGeneration1 = 0;
            uint160 finalSqrtPriceX96 = sqrtPriceX96;
            uint256 finalAmount0 = 0;
            uint256 finalAmount1 = 0;
            uint256 tips = 0;
            uint256 nonce = 1;
            uint256 blockHeight = block.number;

            // #region create a deal.

            d = Deal({
                caller: caller,
                collateralToken: collateralToken,
                collateralAmount: collateralAmount,
                feeFreeSwapper: feeFreeSwapper,
                feeGeneration0: feeGeneration0,
                feeGeneration1: feeGeneration1,
                finalSqrtPriceX96: finalSqrtPriceX96,
                finalAmount0: finalAmount0,
                finalAmount1: finalAmount1,
                tips: tips,
                nonce: nonce,
                blockHeight: blockHeight
            });

            // #endregion create a deal.
        }

        // #region whitelist collateral.

        address[] memory collaterals = new address[](1);
        collaterals[0] = WETH;

        vm.prank(owner);
        hook.whitelistCollaterals(collaterals);

        // #endregion whitelist collateral.

        // #region create a signature.

        bytes memory signature = getEOASignedDeal(d, signer);

        // #endregion create a signature.

        deal(WETH, caller, 1e18);
        vm.prank(caller);
        IERC20(WETH).approve(address(hook), 1 ether);

        vm.prank(caller);
        hook.openPool(d, signature);
    }

    // #endregion test openPool.

    // #region mock functions.

    function getEOASignedDeal(
        Deal memory deal_,
        uint256 privateKey_
    ) public view returns (bytes memory) {
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                getDomainSeparatorV4(block.chainid, address(hook)),
                keccak256(abi.encode(DEAL_EIP712HASH, deal_))
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey_, digest);

        return abi.encodePacked(r, s, bytes1(v));
    }

    function getDomainSeparatorV4(
        uint256 chainId,
        address hook
    ) public view returns (bytes32 domainSeparator) {
        bytes32 typeHash = keccak256(
            "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
        );
        bytes32 hashedName = keccak256("Builder Hook");
        bytes32 hashedVersion = keccak256("version 1");

        domainSeparator = keccak256(
            abi.encode(
                typeHash, hashedName, hashedVersion, chainId, hook
            )
        );
    }

    // #endregion mock functions.
}
