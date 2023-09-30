// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {IArrakisLPModule} from "../interfaces/IArrakisLPModule.sol";
import {IUniswapV2Factory} from "v2-core/interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Pair} from "v2-core/interfaces/IUniswapV2Pair.sol";
import {IERC20} from "../interfaces/IERC20.sol";
import {FullMath} from "v3-lib-0.8/FullMath.sol";
import {Ownable} from "solady/src/auth/Ownable.sol";

contract UniV2Module is IArrakisLPModule, Ownable {
    error NoLiquidity();
    uint24 internal constant _PIPS = 1000000;

    IUniswapV2Factory internal immutable uniV2Factory;
    IUniswapV2Pair internal immutable pool;
    address public immutable token0;
    address public immutable token1;
    uint256 public immutable initLiquidity;

    constructor(
        IUniswapV2Factory _uniV2Factory,
        address _token0,
        address _token1,
        address _owner,
        uint256 _initLiquidity
    ) {
        pool = IUniswapV2Pair(_uniV2Factory.getPair(_token0, _token1));
        uniV2Factory = _uniV2Factory;
        token0 = _token0;
        token1 = _token1;
        _initializeOwner(_owner);
        initLiquidity = _initLiquidity;
    }

    function deposit(uint256 proportion_)
        external
        onlyOwner
    {
        uint256 totalLiquidity = pool.totalSupply();
        if (totalLiquidity > 0) {
            uint256 myLiquidity = pool.balanceOf(address(this));
            (uint112 total0, uint112 total1,) = pool.getReserves();
            uint256 amount0;
            uint256 amount1;
            if (myLiquidity > 0) {
                amount0 = FullMath.mulDiv(
                    FullMath.mulDiv(total0, myLiquidity, totalLiquidity),
                    proportion_,
                    _PIPS
                );
                amount1 = FullMath.mulDiv(amount0, total1, total0);
            } else {
                if (initLiquidity > 0) {
                    amount0 = FullMath.mulDiv(
                        FullMath.mulDiv(total0, initLiquidity, totalLiquidity),
                        proportion_,
                        _PIPS
                    );
                    amount1 = FullMath.mulDiv(amount0, total1, total0);
                }
            }
            if (amount0 > 0 || amount1 > 0) {
                IERC20(token0).transferFrom(msg.sender, address(pool), amount0);
                IERC20(token1).transferFrom(msg.sender, address(pool), amount1);
                pool.mint(address(this));
            }
        }
    }

    function withdraw(uint24 proportion_)
        external
        onlyOwner
        returns (uint256 amount0, uint256 amount1)
    {
        uint256 myLiquidity = pool.balanceOf(address(this));
        uint256 liquidity = FullMath.mulDiv(myLiquidity, proportion_, _PIPS);
        pool.transfer(address(pool), liquidity);
        (amount0, amount1) = pool.burn(msg.sender);
    }

    function depositLiquidity(uint256 liquidity_) external onlyOwner {
        (uint112 total0, uint112 total1,) = pool.getReserves();
        uint256 totalLiquidity = pool.totalSupply();
        uint256 amount0 = FullMath.mulDiv(
            total0,
            liquidity_,
            totalLiquidity
        );
        uint256 amount1 = FullMath.mulDiv(
            total1,
            liquidity_,
            totalLiquidity
        );
        
        IERC20(token0).transferFrom(msg.sender, address(pool), amount0);
        IERC20(token1).transferFrom(msg.sender, address(pool), amount1);
        pool.mint(address(this));
    }

    function getInits() external view returns (uint256 init0, uint256 init1) {
        (uint112 total0, uint112 total1,) = pool.getReserves();
        uint256 totalLiquidity = pool.totalSupply();
        if (totalLiquidity > 0) {
            init0 = FullMath.mulDiv(
                total0,
                initLiquidity,
                totalLiquidity
            );
            init1 = FullMath.mulDiv(
                init0,
                total1,
                total0
            );
        }
    }

    function totalUnderlying()
        external
        view
        returns (uint256 amount0, uint256 amount1)
    {
        uint256 myLiquidity = pool.balanceOf(address(this));
        uint256 totalLiquidity = pool.totalSupply();
        (uint112 reserves0, uint112 reserves1,) = pool.getReserves();
        amount0 = FullMath.mulDiv(reserves0, myLiquidity, totalLiquidity);
        amount1 = FullMath.mulDiv(reserves1, myLiquidity, totalLiquidity);
    }

    function totalUnderlyingAtPrice(uint256 priceX96_)
        external
        view
        returns (uint256 amount0, uint256 amount1)
    {
        uint256 myLiquidity = pool.balanceOf(address(this));
        uint256 totalLiquidity = pool.totalSupply();
        (uint112 r0, uint112 r1, ) = pool.getReserves();
        uint256 intermediate = _sqrt(r0*r1);
        uint sqrtKX96 = FullMath.mulDiv(intermediate, 1 << 96, totalLiquidity);
        // fair token0 amt: sqrtK * sqrt(px1/px0)
        // fair token1 amt: sqrtK * sqrt(px0/px1)
        uint256 fair0 = FullMath.mulDiv(sqrtKX96, _sqrt(priceX96_), 1 << 144);
        uint256 fair1 = FullMath.mulDiv(sqrtKX96, _sqrt(_inversePrice(priceX96_)), 1 << 144);

        amount0 = FullMath.mulDiv(fair0, myLiquidity, totalLiquidity);
        amount1 = FullMath.mulDiv(fair1, myLiquidity, totalLiquidity);
    }

    function _inversePrice(uint256 priceX96) internal pure returns (uint256) {
        return (1 << 192)/priceX96;
    }

    function _sqrt(uint256 x) internal pure returns (uint256 y) {
        uint256 z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }
}