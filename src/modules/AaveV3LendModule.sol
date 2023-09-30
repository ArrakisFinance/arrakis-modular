// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {IArrakisLPModule} from "../interfaces/IArrakisLPModule.sol";
import {FullMath} from "v3-lib-0.8/FullMath.sol";
import {IATokenExt} from "../interfaces/IATokenExt.sol";
import {IPool} from "aave-v3-core/contracts/interfaces/IPool.sol";
import {Ownable} from "solady/src/auth/Ownable.sol";
import {IERC20} from "../interfaces/IERC20.sol";

contract AaveV3LendModule is IArrakisLPModule, Ownable {
    error NoLiquidity();
    uint24 internal constant _PIPS = 1000000;

    IPool internal immutable pool0;
    IPool internal immutable pool1;
    IATokenExt internal immutable aToken0;
    IATokenExt internal immutable aToken1;
    uint256 internal immutable _init0;
    uint256 internal immutable _init1;
    address public immutable token0;
    address public immutable token1;

    constructor(
        IATokenExt _aToken0,
        IATokenExt _aToken1,
        address _owner,
        uint256 _init0_,
        uint256 _init1_
    ) Ownable() {
        aToken0 = _aToken0;
        aToken1 = _aToken1;
        pool0 = _aToken0.POOL();
        pool1 = _aToken1.POOL();
        token0 = _aToken0.UNDERLYING_ASSET_ADDRESS();
        token1 = _aToken1.UNDERLYING_ASSET_ADDRESS();
        _initializeOwner(_owner);
        _init0 = _init0_;
        _init1 = _init1_;
    }

    function deposit(uint256 proportion_)
        external
        onlyOwner
    {
        uint256 bal0 = aToken0.balanceOf(address(this));
        uint256 bal1 = aToken1.balanceOf(address(this));
        uint256 amount0;
        uint256 amount1;
        if (bal0 > 0 || bal1 > 0) {
            amount0 = FullMath.mulDiv(bal0, proportion_, _PIPS);
            amount1 = FullMath.mulDiv(bal1, proportion_, _PIPS);
        } else {
            amount0 = FullMath.mulDiv(_init0, proportion_, _PIPS);
            amount1 = FullMath.mulDiv(_init1, proportion_, _PIPS);
        }
        
        if (amount0 > 0) {
            IERC20(token0).transferFrom(msg.sender, address(this), amount0);
            IERC20(token0).approve(address(pool0), amount0);
            pool0.supply(token0, amount0, address(this), 0);
        }
        if (amount1 > 0) {
            IERC20(token1).transferFrom(msg.sender, address(this), amount1);
            IERC20(token1).approve(address(pool1), amount1);
            pool1.supply(token1, amount1, address(this), 0);
        }
    }

    function withdraw(uint24 proportion_)
        external
        onlyOwner
        returns (uint256 amount0, uint256 amount1)
    {
        amount0 = FullMath.mulDiv(aToken0.balanceOf(address(this)), proportion_, _PIPS);
        amount1 = FullMath.mulDiv(aToken1.balanceOf(address(this)), proportion_, _PIPS);

        if (amount0 > 0) pool0.withdraw(token0, amount0, msg.sender);
        if (amount1 > 0) pool1.withdraw(token1, amount1, msg.sender);
    }

    function supply(uint256 amount0_, uint256 amount1_) external onlyOwner {
        if (amount0_ > 0) {
            IERC20(token0).transferFrom(msg.sender, address(this), amount0_);
            IERC20(token0).approve(address(pool0), amount0_);
            pool0.supply(token0, amount0_, address(this), 0);
        }
        if (amount1_ > 0) {
            IERC20(token1).transferFrom(msg.sender, address(this), amount1_);
            IERC20(token1).approve(address(pool1), amount1_);
            pool1.supply(token1, amount1_, address(this), 0);
        }
    }

    function take(uint256 amount0_, uint256 amount1_) external onlyOwner {
        if (amount0_ > 0) pool0.withdraw(token0, amount0_, msg.sender);
        if (amount1_ > 0) pool1.withdraw(token1, amount1_, msg.sender);
    }

    function getInits() external view returns (uint256, uint256) {
        return (_init0, _init1);
    }

    function totalUnderlying()
        external
        view
        returns (uint256 amount0, uint256 amount1)
    {
        return _totalUnderlying();
    }

    function totalUnderlyingAtPrice(uint256)
        external
        view
        returns (uint256 amount0, uint256 amount1)
    {
        return _totalUnderlying();
    }

    function _totalUnderlying()
        internal
        view
        returns (uint256 amount0, uint256 amount1)
    {
        amount0 = aToken0.balanceOf(address(this));
        amount1 = aToken1.balanceOf(address(this));
    }
}