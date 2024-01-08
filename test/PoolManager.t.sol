// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {console} from "forge-std/console.sol";
import "forge-std/Test.sol";
import {PoolManager} from "@uniswap/v4-core/src/PoolManager.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolIdLibrary, PoolId} from "@uniswap/v4-core/src/types/PoolId.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {FeeLibrary} from "@uniswap/v4-core/src/libraries/FeeLibrary.sol";
import {FixedPoint128} from "@uniswap/v4-core/src/libraries/FixedPoint128.sol";
import {Position} from "@uniswap/v4-core/src/libraries/Position.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {FullMath} from "@uniswap/v4-core/src/libraries/FullMath.sol";
import {Pool} from "@uniswap/v4-core/src/libraries/Pool.sol";
import {IERC20, ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

contract SimpleERC20 is ERC20 {
    constructor(
        string memory name_,
        string memory symbol_
    ) ERC20(name_, symbol_) {}
}

contract PoolManagerTest is Test {
    // #region properties.

    PoolManager public poolManager;
    IERC20 public tokenA;
    IERC20 public tokenB;
    PoolKey public poolKey;
    uint160 public sqrtPriceX96;

    // #endregion properties.

    function setUp() public {
        poolManager = new PoolManager(0);
        // #region initialize pool.

        tokenA = new SimpleERC20("Token A", "TOKA");
        tokenB = new SimpleERC20("Token B", "TOKB");

        Currency currency0 = address(tokenA) > address(tokenB)
            ? Currency.wrap(address(tokenB))
            : Currency.wrap(address(tokenA));
        Currency currency1 = address(tokenA) > address(tokenB)
            ? Currency.wrap(address(tokenA))
            : Currency.wrap(address(tokenB));

        poolKey = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: 10000,
            tickSpacing: 10,
            hooks: IHooks(address(0))
        });

        sqrtPriceX96 = TickMath.getSqrtRatioAtTick(0);

        poolManager.lock(address(this), abi.encode(2));

        // #endregion initialize pool.
    }

    function lockAcquired(
        address caller,
        bytes calldata data
    ) public returns (bytes memory) {
        uint256 typeOfLockAcquired = abi.decode(data, (uint256));

        if (typeOfLockAcquired == 0) _lockAcquiredAddPosition();
        if (typeOfLockAcquired == 1) _lockAcquiredSwap();
        if (typeOfLockAcquired == 2)
            poolManager.initialize(poolKey, sqrtPriceX96, "");
    }

    function testExtSload() public {
        poolManager.lock(address(this), abi.encode(0));

        // #region swap.
        poolManager.lock(address(this), abi.encode(1));
        // #endregion swap.

        uint256 POOL_SLOT = 6;

        bytes32 poolId = PoolId.unwrap(PoolIdLibrary.toId(poolKey));

        // bytes memory position = poolManager.extsload(
        //     bytes32(
        //         uint256(
        //             keccak256(
        //                 abi.encode(
        //                     keccak256(
        //                         abi.encodePacked(
        //                             address(this),
        //                             int24(-10),
        //                             int24(10)
        //                         )
        //                     ),
        //                     bytes32(
        //                         uint256(
        //                             keccak256(abi.encode(poolId, POOL_SLOT))
        //                         ) + 6
        //                     )
        //                 )
        //             )
        //         )
        //     ),
        //     3
        // );

        // (
        //     uint128 liquidity,
        //     // fee growth per unit of liquidity as of the last update to liquidity or fees owed
        //     uint256 feeGrowthInside0LastX128,
        //     uint256 feeGrowthInside1LastX128
        // ) = abi.decode(position, (uint128, uint256, uint256));

        // bytes memory value = poolManager.extsload(
        //     bytes32(uint256(keccak256(abi.encode(poolId, POOL_SLOT))) + 1),
        //     2
        // );

        // (uint256 feeGrowthGlobal0X128, uint256 feeGrowthGlobal1X128) = abi
        //     .decode(value, (uint256, uint256));

        // bytes memory tickInfo = poolManager.extsload(
        //     bytes32(
        //         uint256(
        //             keccak256(
        //                 abi.encode(
        //                     int24(-10),
        //                     bytes32(
        //                         uint256(
        //                             keccak256(abi.encode(poolId, POOL_SLOT))
        //                         ) + 4
        //                     )
        //                 )
        //             )
        //         )
        //     ),
        //     3
        // );
        // console.logString("TOTO");

        // (
        //     bytes32 toto,
        //     uint256 feeGrowthOutside0X128,
        //     uint256 feeGrowthOutside1X128
        // ) = abi.decode(tickInfo, (bytes32, uint256, uint256));

        // console.logUint(liquidity);
        // console.log(1 ether);
        // console.log(feeGrowthInside0LastX128);
        // console.log(feeGrowthInside1LastX128);
        // console.log(feeGrowthGlobal0X128);
        // console.log(feeGrowthGlobal1X128);
        // console.log(feeGrowthOutside0X128);
        // console.log(feeGrowthOutside1X128);

        (
            uint256 feeGrowthInside0X128,
            uint256 feeGrowthInside1X128
        ) = _getFeeGrowthInside(poolKey, -10, 10);

        Position.Info memory positionInfo = poolManager.getPosition(
            PoolId.wrap(poolId),
            address(this),
            -10,
            10
        );

        (uint256 feesOwed0, uint256 feesOwed1) = _getFeesOwned(
            positionInfo,
            feeGrowthInside0X128,
            feeGrowthInside1X128
        );
    }

    // #region internal functions.

    function _getFeeGrowthInside(
        PoolKey memory poolKey_,
        int24 tickLower_,
        int24 tickUpper_
    )
        internal
        view
        returns (uint256 feeGrowthInside0X128, uint256 feeGrowthInside1X128)
    {
        uint256 POOL_SLOT = 6;
        bytes32 poolId = PoolId.unwrap(PoolIdLibrary.toId(poolKey_));

        // #region tickInfo Lower tick.
        bytes memory tILower = poolManager.extsload(
            bytes32(
                uint256(
                    keccak256(
                        abi.encode(
                            tickLower_,
                            bytes32(
                                uint256(
                                    keccak256(abi.encode(poolId, POOL_SLOT))
                                ) + 4
                            )
                        )
                    )
                )
            ),
            3
        );

        (
            ,
            uint256 feeGrowthOutside0X128Lower,
            uint256 feeGrowthOutside1X128Lower
        ) = abi.decode(tILower, (uint256, uint256, uint256));
        // #endregion tickInfo Lower tick.

        // #region tickInfo Upper tick.
        bytes memory tIUpper = poolManager.extsload(
            bytes32(
                uint256(
                    keccak256(
                        abi.encode(
                            tickUpper_,
                            bytes32(
                                uint256(
                                    keccak256(abi.encode(poolId, POOL_SLOT))
                                ) + 4
                            )
                        )
                    )
                )
            ),
            3
        );

        (
            ,
            uint256 feeGrowthOutside0X128Upper,
            uint256 feeGrowthOutside1X128Upper
        ) = abi.decode(tIUpper, (uint256, uint256, uint256));
        // #endregion tickInfo Upper tick.
        // #region get slot0.

        (uint256 price, int24 tickCurrent, ) = poolManager.getSlot0(
            PoolId.wrap(poolId)
        );

        // #endregion get slot0.
        // #region get slot0 through extsload.

        {
            bytes memory slot0Data = poolManager.extsload(
                bytes32(uint256(keccak256(abi.encode(poolId, 6)))),
                4
            );

            // console.logBytes(slot0Data);

            {
                {
                    (
                        bytes32 slot0,
                        uint256 feeGrowthGlobal0X128,
                        uint256 feeGrowthGlobal1X128,
                        uint128 liquidity
                    ) = abi.decode(
                            slot0Data,
                            (bytes32, uint256, uint256, uint128)
                        );
                }

                uint128 liquidity = poolManager.getLiquidity(
                    PoolId.wrap(poolId),
                    address(this),
                    -10,
                    10
                );
            }
        }
        // #endregion get slot0 extsload.
        // #region pool global fees.

        (uint256 feeGrowthGlobal0X128, uint256 feeGrowthGlobal1X128) = abi
            .decode(
                poolManager.extsload(
                    bytes32(
                        uint256(keccak256(abi.encode(poolId, POOL_SLOT))) + 1
                    ),
                    2
                ),
                (uint256, uint256)
            );

        // #endregion pool global fees.

        unchecked {
            if (tickCurrent < tickLower_) {
                feeGrowthInside0X128 =
                    feeGrowthOutside0X128Lower -
                    feeGrowthOutside0X128Upper;
                feeGrowthInside1X128 =
                    feeGrowthOutside1X128Lower -
                    feeGrowthOutside1X128Upper;
            } else if (tickCurrent >= tickUpper_) {
                feeGrowthInside0X128 =
                    feeGrowthOutside0X128Upper -
                    feeGrowthOutside0X128Lower;
                feeGrowthInside1X128 =
                    feeGrowthOutside1X128Upper -
                    feeGrowthOutside1X128Lower;
            } else {
                feeGrowthInside0X128 =
                    feeGrowthGlobal0X128 -
                    feeGrowthOutside0X128Lower -
                    feeGrowthOutside0X128Upper;
                feeGrowthInside1X128 =
                    feeGrowthGlobal1X128 -
                    feeGrowthOutside1X128Lower -
                    feeGrowthOutside1X128Upper;
            }
        }
    }

    function _getFeesOwned(
        Position.Info memory self,
        uint256 feeGrowthInside0X128,
        uint256 feeGrowthInside1X128
    ) internal returns (uint256 feesOwed0, uint256 feesOwed1) {
        unchecked {
            feesOwed0 = FullMath.mulDiv(
                feeGrowthInside0X128 - self.feeGrowthInside0LastX128,
                self.liquidity,
                FixedPoint128.Q128
            );
            feesOwed1 = FullMath.mulDiv(
                feeGrowthInside1X128 - self.feeGrowthInside1LastX128,
                self.liquidity,
                FixedPoint128.Q128
            );
        }
    }

    function _lockAcquiredSwap() internal {
        // #region simulate a swap.

        IPoolManager.SwapParams memory swapParams = IPoolManager.SwapParams({
            zeroForOne: true,
            amountSpecified: 34993002,
            sqrtPriceLimitX96: TickMath.getSqrtRatioAtTick(-10)
        });

        poolManager.swap(poolKey, swapParams, "");

        int256 due0 = poolManager.currencyDelta(
            address(this),
            poolKey.currency0
        );
        int256 due1 = poolManager.currencyDelta(
            address(this),
            poolKey.currency1
        );

        address token0 = address(Currency.unwrap(poolKey.currency0));

        deal(token0, address(this), SafeCast.toUint256(due0));

        IERC20(address(Currency.unwrap(poolKey.currency0))).transfer(
            address(poolManager),
            SafeCast.toUint256(due0)
        );
        poolManager.settle(poolKey.currency0);
        poolManager.take(
            poolKey.currency1,
            address(this),
            SafeCast.toUint256(-due1)
        );

        // #endregion simulate a swap.
    }

    function _lockAcquiredAddPosition() internal {
        IPoolManager.ModifyPositionParams
            memory modifyPositionParam = IPoolManager.ModifyPositionParams({
                tickLower: -10,
                tickUpper: 10,
                liquidityDelta: 1 ether
            });

        poolManager.modifyPosition(poolKey, modifyPositionParam, "");

        int256 due0 = poolManager.currencyDelta(
            address(this),
            poolKey.currency0
        );
        int256 due1 = poolManager.currencyDelta(
            address(this),
            poolKey.currency1
        );

        address token0 = address(Currency.unwrap(poolKey.currency0));
        address token1 = address(Currency.unwrap(poolKey.currency1));

        deal(token0, address(this), SafeCast.toUint256(due0));
        deal(token1, address(this), SafeCast.toUint256(due1));

        IERC20(address(Currency.unwrap(poolKey.currency0))).transfer(
            address(poolManager),
            SafeCast.toUint256(due0)
        );
        poolManager.settle(poolKey.currency0);
        IERC20(address(Currency.unwrap(poolKey.currency1))).transfer(
            address(poolManager),
            SafeCast.toUint256(due1)
        );
        poolManager.settle(poolKey.currency1);

        due0 = poolManager.currencyDelta(address(this), poolKey.currency0);
        due1 = poolManager.currencyDelta(address(this), poolKey.currency1);
    }

    // #endregion internal functions.
}
