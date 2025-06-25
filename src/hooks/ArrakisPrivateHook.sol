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

    // #region modifiers.

    /// @notice Modifier that restricts access to only the module associated with the pool
    /// @param poolKey_ The pool key to check the module for
    /// @param sender_ The address attempting to call the function
    /// @dev This modifier can be reused by contracts that inherit from ArrakisPrivateHook
    /// @dev Reverts with OnlyModule error if the sender is not the authorized module
    modifier onlyModule(PoolKey calldata poolKey_, address sender_) {
        FeesData memory _feesData = feesData[poolKey_.toId()];

        if (_feesData.module != sender_) {
            revert OnlyModule();
        }

        _;
    }

    // #endregion modifiers.

    mapping(PoolId => FeesData) public feesData;

    constructor(
        address manager_
    ) {
        if (manager_ == address(0)) {
            revert AddressZero();
        }

        _validateHookAddress(this);

        manager = manager_;
    }

    /// @inheritdoc IArrakisPrivateHook
    function setFees(
        PoolKey calldata poolKey_,
        FeesData calldata data_
    ) external {
        if (data_.module == address(0)) {
            revert AddressZero();
        }

        address _vault =
            address(IArrakisLPModule(data_.module).metaVault());

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

        uint24 zeroForOneFee =
            data_.zeroForOneFee | LPFeeLibrary.OVERRIDE_FEE_FLAG;
        uint24 oneForZeroFee =
            data_.oneForZeroFee | LPFeeLibrary.OVERRIDE_FEE_FLAG;

        feesData[poolId] = FeesData({
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
    )
        external
        virtual
        onlyModule(poolKey_, sender)
        returns (bytes4)
    {
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

        lpFeeOverride =
            _overrideFees(poolKey_, swapParams_.zeroForOne);
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

    /// @inheritdoc IArrakisPrivateHook
    function getFeesData(
        PoolId id_
    )
        external
        view
        returns (
            address module,
            uint24 zeroForOneFee,
            uint24 oneForZeroFee
        )
    {
        return (
            feesData[id_].module,
            feesData[id_].zeroForOneFee.removeOverrideFlag(),
            feesData[id_].oneForZeroFee.removeOverrideFlag()
        );
    }

    // #endregion view functions.

    /// @inheritdoc IArrakisPrivateHook
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

    // #region internal functions.

    /// @notice Returns the fee override for the given pool and swap direction.
    /// @param poolKey_ The pool key.
    /// @param zeroForOne_ The swap direction.
    /// @return lpFeeOverride The fee override value.
    function _overrideFees(
        PoolKey calldata poolKey_,
        bool zeroForOne_
    ) internal view returns (uint24 lpFeeOverride) {
        FeesData memory _feesData = feesData[poolKey_.toId()];

        if (_feesData.module == address(0)) {
            revert ModuleNotSet();
        }

        lpFeeOverride = zeroForOne_
            ? _feesData.zeroForOneFee
            : _feesData.oneForZeroFee;
    }

    /// @notice Validates that the given hook address has the correct permissions.
    /// @param _this The IHooks instance to validate.
    function _validateHookAddress(
        IHooks _this
    ) internal pure virtual {
        Hooks.validateHookPermissions(_this, getHookPermissions());
    }

    // #endregion internal functions.
}
