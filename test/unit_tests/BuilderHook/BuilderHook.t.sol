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
import {
    PIPS,
    NATIVE_COIN,
    BASE
} from "../../../src/constants/CArrakis.sol";
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
import {LPFeeLibrary} from
    "@uniswap/v4-core/src/libraries/LPFeeLibrary.sol";
// #endregion uniswap v4.

import {SignatureChecker} from
    "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeCast} from
    "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

// #region mock contracts.

import {GuardianMock} from "./mocks/Guardian.sol";
import {ArrakisMetaVaultMock} from "./mocks/ArrakisMetaVault.sol";
import {SimpleSwapper} from "./mocks/SimpleSwapper.sol";

// #endregion mock contracts.

contract BuilderHookTest is TestWrapper {
    using StateLibrary for IPoolManager;
    using TransientStateLibrary for IPoolManager;
    using PoolIdLibrary for PoolKey;
    using BuilderDeal for Deal;
    using SignatureChecker for address;
    using Address for address payable;

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
    SimpleSwapper public simpleSwapper;

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

        // #region create simple swapper.

        simpleSwapper = new SimpleSwapper(address(poolManager));

        // #endregion create simple swapper.

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
            fee: LPFeeLibrary.DYNAMIC_FEE_FLAG,
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
        Deal memory d;
        address caller;

        {
            caller = vm.addr(uint256(keccak256(abi.encode("Caller"))));
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

        vm.expectRevert(IBuilderHook.CannotReOpenThePool.selector);
        vm.prank(caller);
        hook.openPool(d, signature);
    }

    function testOpenPoolNotSameBlockHeight() public {
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
            blockHeight: blockHeight
        });

        // #endregion create a deal.

        // #region create a signature.

        bytes memory signature = getEOASignedDeal(deal, signer);

        // #endregion create a signature.

        vm.expectRevert(IBuilderHook.NotSameBlockHeight.selector);
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
            caller = vm.addr(uint256(keccak256(abi.encode("Caller"))));
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

    function testOpenPoolNotEnoughNativeCoinSent() public {
        Deal memory d;
        address caller;

        {
            caller = vm.addr(uint256(keccak256(abi.encode("Caller"))));
            address collateralToken = NATIVE_COIN;
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
                blockHeight: blockHeight
            });

            // #endregion create a deal.
        }

        // #region whitelist collateral.

        address[] memory collaterals = new address[](1);
        collaterals[0] = NATIVE_COIN;

        vm.prank(owner);
        hook.whitelistCollaterals(collaterals);

        // #endregion whitelist collateral.

        // #region create a signature.

        bytes memory signature = getEOASignedDeal(d, signer);

        // #endregion create a signature.

        deal(caller, 1e18);

        vm.prank(caller);
        vm.expectRevert(IBuilderHook.NotEnoughNativeCoinSent.selector);
        hook.openPool(d, signature);
    }

    function testOpenPool() public {
        Deal memory d;
        address caller;

        {
            caller = vm.addr(uint256(keccak256(abi.encode("Caller"))));
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

    function testOpenPoolNativeCoin() public {
        Deal memory d;
        address caller;

        {
            caller = vm.addr(uint256(keccak256(abi.encode("Caller"))));
            address collateralToken = NATIVE_COIN;
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
                blockHeight: blockHeight
            });

            // #endregion create a deal.
        }

        // #region whitelist collateral.

        address[] memory collaterals = new address[](1);
        collaterals[0] = NATIVE_COIN;

        vm.prank(owner);
        hook.whitelistCollaterals(collaterals);

        // #endregion whitelist collateral.

        // #region create a signature.

        bytes memory signature = getEOASignedDeal(d, signer);

        // #endregion create a signature.

        deal(caller, 1e18);
        bytes memory da = abi.encodeWithSelector(BuilderHook.openPool.selector, d, signature);

        vm.prank(caller);
        payable(address(hook)).functionCallWithValue(da, 1 ether);
    }

    // #endregion test openPool.

    // #region test closePool.

    function testClosePoolNotSameBlockHeight() public {
        // #region open the pool.

        Deal memory d;
        address caller;

        {
            caller = vm.addr(uint256(keccak256(abi.encode("Caller"))));
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

        // #endregion open the pool.

        // #region close the pool.

        address receiver =
            vm.addr(uint256(keccak256(abi.encode("Receiver"))));
        d.blockHeight = block.number + 1;

        vm.prank(caller);
        vm.expectRevert(IBuilderHook.NotSameBlockHeight.selector);
        hook.closePool(d, receiver);

        // #endregion close the pool.
    }

    function testClosePoolOnlyCaller() public {
        // #region open the pool.

        Deal memory d;
        address caller;

        {
            caller = vm.addr(uint256(keccak256(abi.encode("Caller"))));
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

        // #endregion open the pool.

        // #region close the pool.

        address receiver =
            vm.addr(uint256(keccak256(abi.encode("Receiver"))));

        vm.expectRevert(IBuilderHook.OnlyCaller.selector);
        hook.closePool(d, receiver);

        // #endregion close the pool.
    }

    function testClosePoolNotRightDeal() public {
        // #region open the pool.

        Deal memory d;
        address caller;

        {
            caller = vm.addr(uint256(keccak256(abi.encode("Caller"))));
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

        // #endregion open the pool.

        // #region close the pool.

        address receiver =
            vm.addr(uint256(keccak256(abi.encode("Receiver"))));

        d.feeGeneration0 = d.feeGeneration0 + 1;

        vm.expectRevert(IBuilderHook.NotRightDeal.selector);
        vm.prank(caller);
        hook.closePool(d, receiver);

        // #endregion close the pool.
    }

    function testClosePoolNotEnoughFeeGenerated0() public {
        // #region open the pool.

        Deal memory d;
        address caller;

        {
            caller = vm.addr(uint256(keccak256(abi.encode("Caller"))));
            address collateralToken = WETH;
            uint256 collateralAmount = 1 ether;
            address feeFreeSwapper = vm.addr(
                uint256(keccak256(abi.encode("Fee Free Swapper")))
            );
            uint256 feeGeneration0 = 1;
            uint256 feeGeneration1 = 0;
            uint160 finalSqrtPriceX96 = sqrtPriceX96;
            uint256 finalAmount0 = 0;
            uint256 finalAmount1 = 0;
            uint256 tips = 0;
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

        // #endregion open the pool.

        // #region close the pool.

        address receiver =
            vm.addr(uint256(keccak256(abi.encode("Receiver"))));

        vm.expectRevert(IBuilderHook.NotEnoughFeeGenerated.selector);
        vm.prank(caller);
        hook.closePool(d, receiver);

        // #endregion close the pool.
    }

    function testClosePoolNotEnoughFeeGenerated1() public {
        // #region open the pool.

        Deal memory d;
        address caller;

        {
            caller = vm.addr(uint256(keccak256(abi.encode("Caller"))));
            address collateralToken = WETH;
            uint256 collateralAmount = 1 ether;
            address feeFreeSwapper = vm.addr(
                uint256(keccak256(abi.encode("Fee Free Swapper")))
            );
            uint256 feeGeneration0 = 0;
            uint256 feeGeneration1 = 1;
            uint160 finalSqrtPriceX96 = sqrtPriceX96;
            uint256 finalAmount0 = 0;
            uint256 finalAmount1 = 0;
            uint256 tips = 0;
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

        // #endregion open the pool.

        // #region close the pool.

        address receiver =
            vm.addr(uint256(keccak256(abi.encode("Receiver"))));

        vm.expectRevert(IBuilderHook.NotEnoughFeeGenerated.selector);
        vm.prank(caller);
        hook.closePool(d, receiver);

        // #endregion close the pool.
    }

    function testClosePoolNotEnoughFeeGenerated0And1() public {
        // #region open the pool.

        Deal memory d;
        address caller;

        {
            caller = vm.addr(uint256(keccak256(abi.encode("Caller"))));
            address collateralToken = WETH;
            uint256 collateralAmount = 1 ether;
            address feeFreeSwapper = vm.addr(
                uint256(keccak256(abi.encode("Fee Free Swapper")))
            );
            uint256 feeGeneration0 = 1;
            uint256 feeGeneration1 = 1;
            uint160 finalSqrtPriceX96 = sqrtPriceX96;
            uint256 finalAmount0 = 0;
            uint256 finalAmount1 = 0;
            uint256 tips = 0;
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

        // #endregion open the pool.

        // #region close the pool.

        address receiver =
            vm.addr(uint256(keccak256(abi.encode("Receiver"))));

        vm.expectRevert(IBuilderHook.NotEnoughFeeGenerated.selector);
        vm.prank(caller);
        hook.closePool(d, receiver);

        // #endregion close the pool.
    }

    function testClosePoolWrongFinalState0() public {
        // #region open the pool.

        Deal memory d;
        address caller;

        {
            caller = vm.addr(uint256(keccak256(abi.encode("Caller"))));
            address collateralToken = WETH;
            uint256 collateralAmount = 1 ether;
            address feeFreeSwapper = vm.addr(
                uint256(keccak256(abi.encode("Fee Free Swapper")))
            );
            uint256 feeGeneration0 = 0;
            uint256 feeGeneration1 = 0;
            uint160 finalSqrtPriceX96 = sqrtPriceX96;
            uint256 finalAmount0 = 1;
            uint256 finalAmount1 = 0;
            uint256 tips = 0;
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

        // #endregion open the pool.

        // #region close the pool.

        address receiver =
            vm.addr(uint256(keccak256(abi.encode("Receiver"))));

        vm.expectRevert(IBuilderHook.WrongFinalState.selector);
        vm.prank(caller);
        hook.closePool(d, receiver);

        // #endregion close the pool.
    }

    function testClosePoolWrongFinalState1() public {
        // #region open the pool.

        Deal memory d;
        address caller;

        {
            caller = vm.addr(uint256(keccak256(abi.encode("Caller"))));
            address collateralToken = WETH;
            uint256 collateralAmount = 1 ether;
            address feeFreeSwapper = vm.addr(
                uint256(keccak256(abi.encode("Fee Free Swapper")))
            );
            uint256 feeGeneration0 = 0;
            uint256 feeGeneration1 = 0;
            uint160 finalSqrtPriceX96 = sqrtPriceX96;
            uint256 finalAmount0 = 0;
            uint256 finalAmount1 = 1;
            uint256 tips = 0;
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

        // #endregion open the pool.

        // #region close the pool.

        address receiver =
            vm.addr(uint256(keccak256(abi.encode("Receiver"))));

        vm.expectRevert(IBuilderHook.WrongFinalState.selector);
        vm.prank(caller);
        hook.closePool(d, receiver);

        // #endregion close the pool.
    }

    function testClosePoolWrongFinalState0And1() public {
        // #region open the pool.

        Deal memory d;
        address caller;

        {
            caller = vm.addr(uint256(keccak256(abi.encode("Caller"))));
            address collateralToken = WETH;
            uint256 collateralAmount = 1 ether;
            address feeFreeSwapper = vm.addr(
                uint256(keccak256(abi.encode("Fee Free Swapper")))
            );
            uint256 feeGeneration0 = 0;
            uint256 feeGeneration1 = 0;
            uint160 finalSqrtPriceX96 = sqrtPriceX96;
            uint256 finalAmount0 = 1;
            uint256 finalAmount1 = 1;
            uint256 tips = 0;
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

        // #endregion open the pool.

        // #region close the pool.

        address receiver =
            vm.addr(uint256(keccak256(abi.encode("Receiver"))));

        vm.expectRevert(IBuilderHook.WrongFinalState.selector);
        vm.prank(caller);
        hook.closePool(d, receiver);

        // #endregion close the pool.
    }

    function testClosePoolWrongFinalSqrtPrice() public {
        // #region open the pool.

        Deal memory d;
        address caller;

        {
            caller = vm.addr(uint256(keccak256(abi.encode("Caller"))));
            address collateralToken = WETH;
            uint256 collateralAmount = 1 ether;
            address feeFreeSwapper = vm.addr(
                uint256(keccak256(abi.encode("Fee Free Swapper")))
            );
            uint256 feeGeneration0 = 0;
            uint256 feeGeneration1 = 0;
            uint160 finalSqrtPriceX96 = sqrtPriceX96 + 1;
            uint256 finalAmount0 = 0;
            uint256 finalAmount1 = 0;
            uint256 tips = 0;
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

        // #endregion open the pool.

        // #region close the pool.

        address receiver =
            vm.addr(uint256(keccak256(abi.encode("Receiver"))));

        vm.expectRevert(IBuilderHook.WrongFinalSqrtPrice.selector);
        vm.prank(caller);
        hook.closePool(d, receiver);

        // #endregion close the pool.
    }

    function testClosePool() public {
        // #region open the pool.

        Deal memory d;
        address caller;

        {
            caller = vm.addr(uint256(keccak256(abi.encode("Caller"))));
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

        // #endregion open the pool.

        // #region close the pool.

        address receiver =
            vm.addr(uint256(keccak256(abi.encode("Receiver"))));

        vm.prank(caller);
        hook.closePool(d, receiver);

        // #endregion close the pool.
    }

    function testClosePoolNativeCoin() public {
        // #region open the pool.

        Deal memory d;
        address caller;

        {
            caller = vm.addr(uint256(keccak256(abi.encode("Caller"))));
            address collateralToken = NATIVE_COIN;
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
                blockHeight: blockHeight
            });

            // #endregion create a deal.
        }

        // #region whitelist collateral.

        address[] memory collaterals = new address[](1);
        collaterals[0] = NATIVE_COIN;

        vm.prank(owner);
        hook.whitelistCollaterals(collaterals);

        // #endregion whitelist collateral.

        // #region create a signature.

        bytes memory signature = getEOASignedDeal(d, signer);

        // #endregion create a signature.

        deal(caller, 1e18);

        vm.prank(caller);
        hook.openPool{value: 1 ether}(d, signature);

        // #endregion open the pool.

        // #region close the pool.

        address receiver =
            vm.addr(uint256(keccak256(abi.encode("Receiver"))));

        vm.prank(caller);
        hook.closePool(d, receiver);

        // #endregion close the pool.
    }

    // #endregion test closePool.

    // #region test whitelist collaterals.

    function testWhitelistCollateralsAddressZero() public {
        address[] memory collaterals = new address[](1);

        vm.prank(owner);
        vm.expectRevert(IPermissionHook.AddressZero.selector);
        hook.whitelistCollaterals(collaterals);
    }

    function testWhitelistCollateralsAlreadyWhitelistedCollateral()
        public
    {
        address[] memory collaterals = new address[](1);
        collaterals[0] = WETH;

        vm.prank(owner);
        hook.whitelistCollaterals(collaterals);

        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(
                IBuilderHook.AlreadyWhitelistedCollateral.selector,
                WETH
            )
        );
        hook.whitelistCollaterals(collaterals);
    }

    // #endregion test whitelist collaterals.

    // #region test blacklist collaterals.

    function testBlacklistCollateralsNotAlreadyACollateral() public {
        address[] memory collaterals = new address[](1);
        collaterals[0] = WETH;

        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(
                IBuilderHook.NotAlreadyACollateral.selector, WETH
            )
        );
        hook.blacklistCollaterals(collaterals);
    }

    function testBlacklistCollaterals() public {
        address[] memory collaterals = new address[](1);
        collaterals[0] = WETH;

        vm.prank(owner);
        hook.whitelistCollaterals(collaterals);

        vm.prank(owner);
        hook.blacklistCollaterals(collaterals);
    }

    // #endregion test blacklist collaterals.

    // #region test getTokens.

    function testGetTokensNativeCoin() public {
        deal(address(hook), 1 ether);

        address receiver =
            vm.addr(uint256(keccak256(abi.encode("Receiver"))));

        vm.prank(owner);
        hook.getTokens(NATIVE_COIN, receiver);
    }

    function testGetTokensWETH() public {
        deal(WETH, address(hook), 1 ether);

        address receiver =
            vm.addr(uint256(keccak256(abi.encode("Receiver"))));

        vm.prank(owner);
        hook.getTokens(WETH, receiver);
    }

    function testGetTokensTokenAddressZero() public {
        address receiver =
            vm.addr(uint256(keccak256(abi.encode("Receiver"))));

        vm.prank(owner);
        vm.expectRevert(IPermissionHook.AddressZero.selector);
        hook.getTokens(address(0), receiver);
    }

    function testGetTokensReceiverAddressZero() public {
        deal(WETH, address(hook), 1 ether);

        address receiver = address(0);

        vm.prank(owner);
        vm.expectRevert(IPermissionHook.AddressZero.selector);
        hook.getTokens(WETH, receiver);
    }

    // #endregion test getTokens.

    // #region test swap.

    function testSwapNoFree() public {
        uint256 init0 = 3000e6;
        uint256 init1 = 1e18;

        address depositor =
            vm.addr(uint256(keccak256(abi.encode("Depositor"))));
        address receiver =
            vm.addr(uint256(keccak256(abi.encode("Receiver"))));
        // #region deposit funds.

        deal(USDC, depositor, init0);
        deal(WETH, depositor, init1);

        vm.startPrank(depositor);
        IERC20(USDC).approve(address(module), init0);
        IERC20(WETH).approve(address(module), init1);
        vm.stopPrank();

        vm.prank(metaVault);
        module.deposit(depositor, BASE);

        // #region assertions.

        assertEq(IERC20(USDC).balanceOf(depositor), 0);
        assertEq(IERC20(WETH).balanceOf(depositor), 0);

        // #endregion assertions.

        // #endregion deposit funds.

        // #region do rebalance.

        int24 tick = TickMath.getTickAtSqrtPrice(sqrtPriceX96);

        int24 tickLower = (tick / 10) * 10 - (2 * 10);
        int24 tickUpper = (tick / 10) * 10 + (2 * 10);

        IUniV4StandardModule.Range memory range = IUniV4StandardModule
            .Range({tickLower: tickLower, tickUpper: tickUpper});

        uint128 liquidity = LiquidityAmounts.getLiquidityForAmounts(
            sqrtPriceX96,
            TickMath.getSqrtPriceAtTick(tickLower),
            TickMath.getSqrtPriceAtTick(tickUpper),
            init0,
            init1
        );

        IUniV4StandardModule.LiquidityRange memory liquidityRange =
        IUniV4StandardModule.LiquidityRange({
            range: range,
            liquidity: SafeCast.toInt128(
                SafeCast.toInt256(uint256(liquidity))
            )
        });

        IUniV4StandardModule.LiquidityRange[] memory liquidityRanges =
            new IUniV4StandardModule.LiquidityRange[](1);

        liquidityRanges[0] = liquidityRange;

        vm.prank(manager);
        module.rebalance(liquidityRanges);

        // #endregion do rebalance.

        // #region open pool and do swap.

        // #region open the pool.

        Deal memory d;
        address caller;

        {
            caller = vm.addr(uint256(keccak256(abi.encode("Caller"))));
            address collateralToken = WETH;
            uint256 collateralAmount = 1 ether;
            address feeFreeSwapper = vm.addr(
                uint256(keccak256(abi.encode("Fee Free Swapper")))
            );
            uint256 feeGeneration0 = 0;
            uint256 feeGeneration1 = 0;
            uint160 finalSqrtPriceX96 =
                1_356_903_004_987_622_777_985_699_151_499_184;
            uint256 finalAmount0 = 1_999_225_106;
            uint256 finalAmount1 = 1_277_829_913_980_718_268;
            uint256 tips = 0;
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

        // #endregion open the pool.

        // #region do swap fee free swap.

        simpleSwapper.setPoolKey(poolKey);
        simpleSwapper.doSwapOne();

        // {
        //     (uint256 amount0, uint256 amount1, uint256 fees0, uint256 fees1) =
        //         module.getAmountsAndFees();

        //     console.logUint(amount0);
        //     console.logUint(amount1);

        //     console.logUint(fees0);
        //     console.logUint(fees1);
        // }

        // {
        //     PoolId poolId = poolKey.toId();
        //     (uint160 sqrt,,,) =
        //         IPoolManager(address(poolManager)).getSlot0(poolId);

        //     console.log("New sqrt price : %d", sqrt);
        // }

        // #endregion do swap fee free swap.

        // #region close the pool.

        vm.prank(caller);
        hook.closePool(d, receiver);

        // #endregion close the pool.

        // #endregion open pool and do swap.
    }

    function testSwapFree() public {
        uint256 init0 = 3000e6;
        uint256 init1 = 1e18;

        address depositor =
            vm.addr(uint256(keccak256(abi.encode("Depositor"))));
        address receiver =
            vm.addr(uint256(keccak256(abi.encode("Receiver"))));
        // #region deposit funds.

        deal(USDC, depositor, init0);
        deal(WETH, depositor, init1);

        vm.startPrank(depositor);
        IERC20(USDC).approve(address(module), init0);
        IERC20(WETH).approve(address(module), init1);
        vm.stopPrank();

        vm.prank(metaVault);
        module.deposit(depositor, BASE);

        // #region assertions.

        assertEq(IERC20(USDC).balanceOf(depositor), 0);
        assertEq(IERC20(WETH).balanceOf(depositor), 0);

        // #endregion assertions.

        // #endregion deposit funds.

        // #region do rebalance.

        int24 tick = TickMath.getTickAtSqrtPrice(sqrtPriceX96);

        int24 tickLower = (tick / 10) * 10 - (2 * 10);
        int24 tickUpper = (tick / 10) * 10 + (2 * 10);

        IUniV4StandardModule.Range memory range = IUniV4StandardModule
            .Range({tickLower: tickLower, tickUpper: tickUpper});

        uint128 liquidity = LiquidityAmounts.getLiquidityForAmounts(
            sqrtPriceX96,
            TickMath.getSqrtPriceAtTick(tickLower),
            TickMath.getSqrtPriceAtTick(tickUpper),
            init0,
            init1
        );

        IUniV4StandardModule.LiquidityRange memory liquidityRange =
        IUniV4StandardModule.LiquidityRange({
            range: range,
            liquidity: SafeCast.toInt128(
                SafeCast.toInt256(uint256(liquidity))
            )
        });

        IUniV4StandardModule.LiquidityRange[] memory liquidityRanges =
            new IUniV4StandardModule.LiquidityRange[](1);

        liquidityRanges[0] = liquidityRange;

        vm.prank(manager);
        module.rebalance(liquidityRanges);

        // #endregion do rebalance.

        // #region open pool and do swap.

        // #region open the pool.

        Deal memory d;
        address caller;

        {
            caller = vm.addr(uint256(keccak256(abi.encode("Caller"))));
            address collateralToken = WETH;
            uint256 collateralAmount = 1 ether;
            address feeFreeSwapper = address(simpleSwapper);
            uint256 feeGeneration0 = 0;
            uint256 feeGeneration1 = 0;
            uint160 finalSqrtPriceX96 =
                1_356_903_004_987_622_777_985_699_151_499_184;
            uint256 finalAmount0 = 1_999_225_106;
            uint256 finalAmount1 = 1_277_829_913_980_718_268;
            uint256 tips = 0;
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

        // #endregion open the pool.

        // #region do swap fee free swap.

        simpleSwapper.setSwapData(abi.encode(d));
        simpleSwapper.setPoolKey(poolKey);
        simpleSwapper.doSwapOne();

        // {
        //     (uint256 amount0, uint256 amount1,,) =
        //         module.getAmountsAndFees();

        //     console.logUint(amount0);
        //     console.logUint(amount1);
        // }

        // {
        //     PoolId poolId = poolKey.toId();
        //     (uint160 sqrt,,,) =
        //         IPoolManager(address(poolManager)).getSlot0(poolId);

        //     console.log("New sqrt price : %d", sqrt);
        // }

        // #endregion do swap fee free swap.

        // #region close the pool.

        vm.prank(caller);
        hook.closePool(d, receiver);

        // #endregion close the pool.

        // #endregion open pool and do swap.
    }

    function testSwapPoolNotOpen() public {
        simpleSwapper.setPoolKey(poolKey);
        vm.expectRevert(IBuilderHook.PoolNotOpen.selector);
        simpleSwapper.doSwapOne();
    }

    function testSwapNotRightDeal() public {
        uint256 init0 = 3000e6;
        uint256 init1 = 1e18;

        address depositor =
            vm.addr(uint256(keccak256(abi.encode("Depositor"))));
        address receiver =
            vm.addr(uint256(keccak256(abi.encode("Receiver"))));
        // #region deposit funds.

        deal(USDC, depositor, init0);
        deal(WETH, depositor, init1);

        vm.startPrank(depositor);
        IERC20(USDC).approve(address(module), init0);
        IERC20(WETH).approve(address(module), init1);
        vm.stopPrank();

        vm.prank(metaVault);
        module.deposit(depositor, BASE);

        // #region assertions.

        assertEq(IERC20(USDC).balanceOf(depositor), 0);
        assertEq(IERC20(WETH).balanceOf(depositor), 0);

        // #endregion assertions.

        // #endregion deposit funds.

        // #region do rebalance.

        int24 tick = TickMath.getTickAtSqrtPrice(sqrtPriceX96);

        int24 tickLower = (tick / 10) * 10 - (2 * 10);
        int24 tickUpper = (tick / 10) * 10 + (2 * 10);

        IUniV4StandardModule.Range memory range = IUniV4StandardModule
            .Range({tickLower: tickLower, tickUpper: tickUpper});

        uint128 liquidity = LiquidityAmounts.getLiquidityForAmounts(
            sqrtPriceX96,
            TickMath.getSqrtPriceAtTick(tickLower),
            TickMath.getSqrtPriceAtTick(tickUpper),
            init0,
            init1
        );

        IUniV4StandardModule.LiquidityRange memory liquidityRange =
        IUniV4StandardModule.LiquidityRange({
            range: range,
            liquidity: SafeCast.toInt128(
                SafeCast.toInt256(uint256(liquidity))
            )
        });

        IUniV4StandardModule.LiquidityRange[] memory liquidityRanges =
            new IUniV4StandardModule.LiquidityRange[](1);

        liquidityRanges[0] = liquidityRange;

        vm.prank(manager);
        module.rebalance(liquidityRanges);

        // #endregion do rebalance.

        // #region open pool and do swap.

        // #region open the pool.

        Deal memory d;
        address caller;

        {
            caller = vm.addr(uint256(keccak256(abi.encode("Caller"))));
            address collateralToken = WETH;
            uint256 collateralAmount = 1 ether;
            address feeFreeSwapper = address(simpleSwapper);
            uint256 feeGeneration0 = 0;
            uint256 feeGeneration1 = 0;
            uint160 finalSqrtPriceX96 =
                1_356_903_004_987_622_777_985_699_151_499_184;
            uint256 finalAmount0 = 1_999_225_106;
            uint256 finalAmount1 = 1_277_829_913_980_718_268;
            uint256 tips = 0;
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

        // #endregion open the pool.

        // #region do swap fee free swap.

        d.feeGeneration0 = d.feeGeneration0 + 1;

        simpleSwapper.setSwapData(abi.encode(d));
        simpleSwapper.setPoolKey(poolKey);
        vm.expectRevert(IBuilderHook.NotRightDeal.selector);
        simpleSwapper.doSwapOne();

        // #endregion do swap fee free swap.

        // #endregion open pool and do swap.
    }

    function testSwapFeeFreeSwapHappened() public {
        uint256 init0 = 3000e6;
        uint256 init1 = 1e18;

        address depositor =
            vm.addr(uint256(keccak256(abi.encode("Depositor"))));
        address receiver =
            vm.addr(uint256(keccak256(abi.encode("Receiver"))));
        // #region deposit funds.

        deal(USDC, depositor, init0);
        deal(WETH, depositor, init1);

        vm.startPrank(depositor);
        IERC20(USDC).approve(address(module), init0);
        IERC20(WETH).approve(address(module), init1);
        vm.stopPrank();

        vm.prank(metaVault);
        module.deposit(depositor, BASE);

        // #region assertions.

        assertEq(IERC20(USDC).balanceOf(depositor), 0);
        assertEq(IERC20(WETH).balanceOf(depositor), 0);

        // #endregion assertions.

        // #endregion deposit funds.

        // #region do rebalance.

        int24 tick = TickMath.getTickAtSqrtPrice(sqrtPriceX96);

        int24 tickLower = (tick / 10) * 10 - (2 * 10);
        int24 tickUpper = (tick / 10) * 10 + (2 * 10);

        IUniV4StandardModule.Range memory range = IUniV4StandardModule
            .Range({tickLower: tickLower, tickUpper: tickUpper});

        uint128 liquidity = LiquidityAmounts.getLiquidityForAmounts(
            sqrtPriceX96,
            TickMath.getSqrtPriceAtTick(tickLower),
            TickMath.getSqrtPriceAtTick(tickUpper),
            init0,
            init1
        );

        IUniV4StandardModule.LiquidityRange memory liquidityRange =
        IUniV4StandardModule.LiquidityRange({
            range: range,
            liquidity: SafeCast.toInt128(
                SafeCast.toInt256(uint256(liquidity))
            )
        });

        IUniV4StandardModule.LiquidityRange[] memory liquidityRanges =
            new IUniV4StandardModule.LiquidityRange[](1);

        liquidityRanges[0] = liquidityRange;

        vm.prank(manager);
        module.rebalance(liquidityRanges);

        // #endregion do rebalance.

        // #region open pool and do swap.

        // #region open the pool.

        Deal memory d;
        address caller;

        {
            caller = vm.addr(uint256(keccak256(abi.encode("Caller"))));
            address collateralToken = WETH;
            uint256 collateralAmount = 1 ether;
            address feeFreeSwapper = address(simpleSwapper);
            uint256 feeGeneration0 = 0;
            uint256 feeGeneration1 = 0;
            uint160 finalSqrtPriceX96 =
                1_356_903_004_987_622_777_985_699_151_499_184;
            uint256 finalAmount0 = 1_999_225_106;
            uint256 finalAmount1 = 1_277_829_913_980_718_268;
            uint256 tips = 0;
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

        // #endregion open the pool.

        // #region do swap fee free swap.

        simpleSwapper.setSwapData(abi.encode(d));
        simpleSwapper.setPoolKey(poolKey);
        simpleSwapper.doSwapOne();

        vm.expectRevert(IBuilderHook.FeeFreeSwapHappened.selector);
        simpleSwapper.doSwapOne();

        // #endregion do swap fee free swap.

        // #endregion open pool and do swap.
    }

    function testSwapNotFeeFreeSwapper() public {
        uint256 init0 = 3000e6;
        uint256 init1 = 1e18;

        address depositor =
            vm.addr(uint256(keccak256(abi.encode("Depositor"))));
        address receiver =
            vm.addr(uint256(keccak256(abi.encode("Receiver"))));
        // #region deposit funds.

        deal(USDC, depositor, init0);
        deal(WETH, depositor, init1);

        vm.startPrank(depositor);
        IERC20(USDC).approve(address(module), init0);
        IERC20(WETH).approve(address(module), init1);
        vm.stopPrank();

        vm.prank(metaVault);
        module.deposit(depositor, BASE);

        // #region assertions.

        assertEq(IERC20(USDC).balanceOf(depositor), 0);
        assertEq(IERC20(WETH).balanceOf(depositor), 0);

        // #endregion assertions.

        // #endregion deposit funds.

        // #region do rebalance.

        int24 tick = TickMath.getTickAtSqrtPrice(sqrtPriceX96);

        int24 tickLower = (tick / 10) * 10 - (2 * 10);
        int24 tickUpper = (tick / 10) * 10 + (2 * 10);

        IUniV4StandardModule.Range memory range = IUniV4StandardModule
            .Range({tickLower: tickLower, tickUpper: tickUpper});

        uint128 liquidity = LiquidityAmounts.getLiquidityForAmounts(
            sqrtPriceX96,
            TickMath.getSqrtPriceAtTick(tickLower),
            TickMath.getSqrtPriceAtTick(tickUpper),
            init0,
            init1
        );

        IUniV4StandardModule.LiquidityRange memory liquidityRange =
        IUniV4StandardModule.LiquidityRange({
            range: range,
            liquidity: SafeCast.toInt128(
                SafeCast.toInt256(uint256(liquidity))
            )
        });

        IUniV4StandardModule.LiquidityRange[] memory liquidityRanges =
            new IUniV4StandardModule.LiquidityRange[](1);

        liquidityRanges[0] = liquidityRange;

        vm.prank(manager);
        module.rebalance(liquidityRanges);

        // #endregion do rebalance.

        // #region open pool and do swap.

        // #region open the pool.

        Deal memory d;
        address caller;

        {
            caller = vm.addr(uint256(keccak256(abi.encode("Caller"))));
            address collateralToken = WETH;
            uint256 collateralAmount = 1 ether;
            address feeFreeSwapper =
                vm.addr(uint256(keccak256(abi.encode(""))));
            uint256 feeGeneration0 = 0;
            uint256 feeGeneration1 = 0;
            uint160 finalSqrtPriceX96 =
                1_356_903_004_987_622_777_985_699_151_499_184;
            uint256 finalAmount0 = 1_999_225_106;
            uint256 finalAmount1 = 1_277_829_913_980_718_268;
            uint256 tips = 0;
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

        // #endregion open the pool.

        // #region do swap fee free swap.

        simpleSwapper.setSwapData(abi.encode(d));
        simpleSwapper.setPoolKey(poolKey);
        vm.expectRevert(IBuilderHook.NotFeeFreeSwapper.selector);
        simpleSwapper.doSwapOne();

        // #endregion do swap fee free swap.

        // #endregion open pool and do swap.
    }

    function testSwapNotSameBlockHeight() public {
        uint256 init0 = 3000e6;
        uint256 init1 = 1e18;

        address depositor =
            vm.addr(uint256(keccak256(abi.encode("Depositor"))));
        address receiver =
            vm.addr(uint256(keccak256(abi.encode("Receiver"))));
        // #region deposit funds.

        deal(USDC, depositor, init0);
        deal(WETH, depositor, init1);

        vm.startPrank(depositor);
        IERC20(USDC).approve(address(module), init0);
        IERC20(WETH).approve(address(module), init1);
        vm.stopPrank();

        vm.prank(metaVault);
        module.deposit(depositor, BASE);

        // #region assertions.

        assertEq(IERC20(USDC).balanceOf(depositor), 0);
        assertEq(IERC20(WETH).balanceOf(depositor), 0);

        // #endregion assertions.

        // #endregion deposit funds.

        // #region do rebalance.

        int24 tick = TickMath.getTickAtSqrtPrice(sqrtPriceX96);

        int24 tickLower = (tick / 10) * 10 - (2 * 10);
        int24 tickUpper = (tick / 10) * 10 + (2 * 10);

        IUniV4StandardModule.Range memory range = IUniV4StandardModule
            .Range({tickLower: tickLower, tickUpper: tickUpper});

        uint128 liquidity = LiquidityAmounts.getLiquidityForAmounts(
            sqrtPriceX96,
            TickMath.getSqrtPriceAtTick(tickLower),
            TickMath.getSqrtPriceAtTick(tickUpper),
            init0,
            init1
        );

        IUniV4StandardModule.LiquidityRange memory liquidityRange =
        IUniV4StandardModule.LiquidityRange({
            range: range,
            liquidity: SafeCast.toInt128(
                SafeCast.toInt256(uint256(liquidity))
            )
        });

        IUniV4StandardModule.LiquidityRange[] memory liquidityRanges =
            new IUniV4StandardModule.LiquidityRange[](1);

        liquidityRanges[0] = liquidityRange;

        vm.prank(manager);
        module.rebalance(liquidityRanges);

        // #endregion do rebalance.

        // #region open pool and do swap.

        // #region open the pool.

        Deal memory d;
        address caller;

        {
            caller = vm.addr(uint256(keccak256(abi.encode("Caller"))));
            address collateralToken = WETH;
            uint256 collateralAmount = 1 ether;
            address feeFreeSwapper = address(simpleSwapper);
            uint256 feeGeneration0 = 0;
            uint256 feeGeneration1 = 0;
            uint160 finalSqrtPriceX96 =
                1_356_903_004_987_622_777_985_699_151_499_184;
            uint256 finalAmount0 = 1_999_225_106;
            uint256 finalAmount1 = 1_277_829_913_980_718_268;
            uint256 tips = 0;
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

        // #endregion open the pool.

        // #region do swap fee free swap.

        vm.roll(d.blockHeight + 1);

        simpleSwapper.setSwapData(abi.encode(d));
        simpleSwapper.setPoolKey(poolKey);
        vm.expectRevert(IBuilderHook.NotSameBlockHeight.selector);
        simpleSwapper.doSwapOne();

        // #endregion do swap fee free swap.

        // #endregion open pool and do swap.
    }

    // #endregion test swap.

    // #region test collaterals.

    function testCollaterals() public {
        // #region add collaterals.

        address[] memory collaterals = new address[](1);
        collaterals[0] = WETH;

        vm.prank(owner);
        hook.whitelistCollaterals(collaterals);

        // #endregion add collaterals.

        address[] memory currentCollaterals = hook.collaterals();

        assert(currentCollaterals.length == collaterals.length);
        assertEq(currentCollaterals[0], WETH);
    }

    // #endregion test collaterals.

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
