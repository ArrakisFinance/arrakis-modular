// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

import {IArrakisPrivateHook} from
    "../interfaces/IArrakisPrivateHook.sol";
import {IArrakisLPModule} from "../interfaces/IArrakisLPModule.sol";
import {IArrakisMetaVault} from "../interfaces/IArrakisMetaVault.sol";
import {IArrakisStandardManager} from
    "../interfaces/IArrakisStandardManager.sol";

import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {IPoolManager} from
    "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {BalanceDelta} from
    "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {BeforeSwapDelta} from
    "@uniswap/v4-core/src/types/BeforeSwapDelta.sol";
import {LPFeeLibrary} from
    "@uniswap/v4-core/src/libraries/LPFeeLibrary.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";

import {Initializable} from
    "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract ArrakisPrivateHook is
    IHooks,
    IArrakisPrivateHook,
    Initializable
{
    using LPFeeLibrary for uint24;

    // #region immutable properties.

    address public immutable manager;

    // #endregion immutable properties.

    address public module;
    address public vault;

    uint256 internal _blockNumber;
    uint24 internal _zeroForOneFee;
    uint24 internal _oneForZeroFee;
    uint24 internal _oldZeroForOneFee;
    uint24 internal _oldOneForZeroFee;

    constructor(
        address manager_
    ) {
        if (manager_ == address(0)) {
            revert AddressZero();
        }

        _validateHookAddress(this);

        manager = manager_;
    }

    function initialize(
        address module_
    ) external initializer {
        if (module_ == address(0)) {
            revert AddressZero();
        }

        module = module_;

        IArrakisMetaVault _vault =
            IArrakisLPModule(module).metaVault();
        vault = address(_vault);
    }

    function setFees(
        uint24 zeroForOneFee_,
        uint24 oneForZeroFee_
    ) external {
        (,,,, address executor,,,) =
            IArrakisStandardManager(manager).vaultInfo(vault);

        if (msg.sender != executor) {
            revert OnlyVaultExecutor();
        }

        // #region checks if fees are valid.

        zeroForOneFee_.validate();
        oneForZeroFee_.validate();

        // #endregion checks if fees are valid.

        _oldZeroForOneFee = _zeroForOneFee;
        _oldOneForZeroFee = _oneForZeroFee;

        _zeroForOneFee =
            zeroForOneFee_ | LPFeeLibrary.OVERRIDE_FEE_FLAG;
        _oneForZeroFee =
            oneForZeroFee_ | LPFeeLibrary.OVERRIDE_FEE_FLAG;
        _blockNumber = block.number + 1;

        // IPoolManager(poolManager).updateDynamicLPFee(poolKey_, fee_);

        emit SetFees(zeroForOneFee_, oneForZeroFee_, block.number + 1);
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
        PoolKey calldata,
        IPoolManager.ModifyLiquidityParams calldata,
        bytes calldata
    ) external virtual returns (bytes4) {
        if (sender != module) {
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
        PoolKey calldata,
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

        if (block.number >= _blockNumber) {
            lpFeeOverride = swapParams_.zeroForOne
                ? _zeroForOneFee
                : _oneForZeroFee;
        } else {
            lpFeeOverride = swapParams_.zeroForOne
                ? _oldZeroForOneFee
                : _oldOneForZeroFee;
        }
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

    function zeroForOneFee() external view returns (uint24) {
        return _zeroForOneFee.removeOverrideFlag();
    }

    function oneForZeroFee() external view returns (uint24) {
        return _oneForZeroFee.removeOverrideFlag();
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
