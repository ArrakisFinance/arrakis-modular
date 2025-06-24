// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

import {IArrakisPrivateHook} from
    "../interfaces/IArrakisPrivateHook.sol";
import {IArrakisLPModule} from "../interfaces/IArrakisLPModule.sol";
import {IArrakisStandardManager} from
    "../interfaces/IArrakisStandardManager.sol";

import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {IPoolManager} from
    "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {
    PoolId,
    PoolIdLibrary
} from "@uniswap/v4-core/src/types/PoolId.sol";
import {BalanceDelta} from
    "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {BeforeSwapDelta} from
    "@uniswap/v4-core/src/types/BeforeSwapDelta.sol";
import {LPFeeLibrary} from
    "@uniswap/v4-core/src/libraries/LPFeeLibrary.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";

contract ArrakisPrivateHook is IHooks, IArrakisPrivateHook {
    using LPFeeLibrary for uint24;
    using PoolIdLibrary for PoolKey;

    // #region immutable properties.

    address public immutable manager;

    // #endregion immutable properties.

    mapping(PoolId => SetFeesData) public feesData;

    constructor(
        address manager_
    ) {
        if (manager_ == address(0)) {
            revert AddressZero();
        }

        _validateHookAddress(this);

        manager = manager_;
    }

    function setFees(
        PoolKey calldata poolKey_,
        SetFeesData calldata data_
    ) external {
        if (data_.module == address(0)) {
            revert AddressZero();
        }

        address _vault = address(IArrakisLPModule(data_.module).metaVault());

        (,,,, address executor,,,) =
            IArrakisStandardManager(manager).vaultInfo(_vault);

        if (msg.sender != executor) {
            revert OnlyVaultExecutor();
        }

        // #region checks if fees are valid.

        data_.zeroForOneFee.validate();
        data_.oneForZeroFee.validate();

        // #endregion checks if fees are valid.

        PoolId poolId = poolKey_.toId();

        uint24 zeroForOneFee = data_.zeroForOneFee | LPFeeLibrary.OVERRIDE_FEE_FLAG;
        uint24 oneForZeroFee = data_.oneForZeroFee | LPFeeLibrary.OVERRIDE_FEE_FLAG;

        feesData[poolId] = SetFeesData({
            module: data_.module,
            zeroForOneFee: zeroForOneFee,
            oneForZeroFee: oneForZeroFee
        });

        emit SetFees(
            poolId,
            data_.module,
            data_.zeroForOneFee,
            data_.oneForZeroFee
        );
    }

    /// @notice The hook called before the state of a pool is initialized.
    /// @dev function not implemented, ArrakisPrivateHook will not support this hook.
    function beforeInitialize(
        address,
        PoolKey calldata,
        uint160
    ) external virtual returns (bytes4) {
        revert NotImplemented();
    }

    /// @notice The hook called after the state of a pool is initialized.
    /// @dev function not implemented, ArrakisPrivateHook will not support this hook.
    function afterInitialize(
        address,
        PoolKey calldata,
        uint160,
        int24
    ) external virtual returns (bytes4) {
        revert NotImplemented();
    }

    /// @notice The hook called before liquidity is added
    /// @param sender The initial msg.sender for the add liquidity call.
    function beforeAddLiquidity(
        address sender,
        PoolKey calldata poolKey_,
        IPoolManager.ModifyLiquidityParams calldata,
        bytes calldata
    ) external virtual returns (bytes4) {
        SetFeesData memory _feesData = feesData[poolKey_.toId()];

        if (sender != _feesData.module) {
            revert OnlyModule();
        }

        return IHooks.beforeAddLiquidity.selector;
    }

    /// @notice The hook called after liquidity is added.
    /// @dev function not implemented, ArrakisPrivateHook will not support this hook.
    function afterAddLiquidity(
        address,
        PoolKey calldata,
        IPoolManager.ModifyLiquidityParams calldata,
        BalanceDelta,
        BalanceDelta,
        bytes calldata
    ) external virtual returns (bytes4, BalanceDelta) {
        revert NotImplemented();
    }

    /// @notice The hook called before liquidity is removed.
    function beforeRemoveLiquidity(
        address,
        PoolKey calldata,
        IPoolManager.ModifyLiquidityParams calldata,
        bytes calldata
    ) external virtual returns (bytes4) {
        revert NotImplemented();
    }

    /// @notice The hook called after liquidity is removed.
    /// @dev function not implemented, ArrakisPrivateHook will not support this hook.
    function afterRemoveLiquidity(
        address,
        PoolKey calldata,
        IPoolManager.ModifyLiquidityParams calldata,
        BalanceDelta,
        BalanceDelta,
        bytes calldata
    ) external virtual returns (bytes4, BalanceDelta) {
        revert NotImplemented();
    }

    /// @notice The hook called before a swap.
    function beforeSwap(
        address,
        PoolKey calldata poolKey_,
        IPoolManager.SwapParams calldata swapParams_,
        bytes calldata
    )
        external
        virtual
        returns (
            bytes4 funcSelector,
            BeforeSwapDelta,
            uint24 lpFeeOverride
        )
    {
        funcSelector = IHooks.beforeSwap.selector;

        SetFeesData memory _feesData = feesData[poolKey_.toId()];

        if (_feesData.module == address(0)) {
            revert ModuleNotSet();
        }

        lpFeeOverride = swapParams_.zeroForOne
            ? _feesData.zeroForOneFee
            : _feesData.oneForZeroFee;
    }

    /// @notice The hook called after a swap.
    /// @dev function not implemented, ArrakisPrivateHook will not support this hook.
    function afterSwap(
        address,
        PoolKey calldata,
        IPoolManager.SwapParams calldata,
        BalanceDelta,
        bytes calldata
    ) external virtual returns (bytes4, int128) {
        revert NotImplemented();
    }

    /// @notice The hook called before donate.
    /// @dev function not implemented, ArrakisPrivateHook will not support this hook.
    function beforeDonate(
        address,
        PoolKey calldata,
        uint256,
        uint256,
        bytes calldata
    ) external virtual returns (bytes4) {
        revert NotImplemented();
    }

    /// @notice The hook called after donate.
    /// @dev function not implemented, ArrakisPrivateHook will not support this hook.
    function afterDonate(
        address,
        PoolKey calldata,
        uint256,
        uint256,
        bytes calldata
    ) external virtual returns (bytes4) {
        revert NotImplemented();
    }

    // #region view functions.

    function zeroForOneFee(
        PoolId id_
    ) external view returns (uint24) {
        return feesData[id_].zeroForOneFee.removeOverrideFlag();
    }

    function oneForZeroFee(
        PoolId id_
    ) external view returns (uint24) {
        return feesData[id_].oneForZeroFee.removeOverrideFlag();
    }

    // #endregion view functions.

    function getHookPermissions()
        public
        pure
        virtual
        returns (Hooks.Permissions memory)
    {
        return Hooks.Permissions({
            beforeInitialize: false,
            afterInitialize: false,
            beforeAddLiquidity: true,
            afterAddLiquidity: false,
            beforeRemoveLiquidity: false,
            afterRemoveLiquidity: false,
            beforeSwap: true,
            afterSwap: false,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    function _validateHookAddress(
        IHooks _this
    ) internal pure virtual {
        Hooks.validateHookPermissions(_this, getHookPermissions());
    }
}
