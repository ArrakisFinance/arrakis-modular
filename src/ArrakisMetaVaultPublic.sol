// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IArrakisMetaVaultPublic} from "./interfaces/IArrakisMetaVaultPublic.sol";
import {IArrakisLPModulePublic} from "./interfaces/IArrakisLPModulePublic.sol";
import {ArrakisMetaVault, PIPS} from "./abstracts/ArrakisMetaVault.sol";
import {PUBLIC_TYPE} from "./constants/CArrakis.sol";

import {ERC20} from "@solady/contracts/tokens/ERC20.sol";

import {FullMath} from "@v3-lib-0.8/contracts/FullMath.sol";

import {Address} from "@openzeppelin/contracts/utils/Address.sol";

contract ArrakisMetaVaultPublic is
    IArrakisMetaVaultPublic,
    ArrakisMetaVault,
    ERC20
{
    using Address for address payable;

    string internal _name;
    string internal _symbol;

    constructor(
        address token0_,
        address token1_,
        address owner_,
        string memory name_,
        string memory symbol_,
        address moduleRegistry_,
        address manager_
    )
        ArrakisMetaVault(
            token0_,
            token1_,
            owner_,
            moduleRegistry_,
            manager_
        )
    {
        _name = name_;
        _symbol = symbol_;
    }

    function mint(
        uint256 shares_,
        address receiver_
    ) external payable returns (uint256 amount0, uint256 amount1) {
        if (shares_ == 0) revert MintZero();
        uint256 supply = totalSupply();

        // should we do a mulDivRoundup
        uint256 proportion = FullMath.mulDiv(
            shares_,
            PIPS,
            supply > 0 ? supply : 1 ether
        );

        if (proportion == 0) revert CannotMintProportionZero();

        if (receiver_ == address(0)) revert AddressZero("Receiver");

        _mint(receiver_, shares_);

        (amount0, amount1) = _deposit(proportion);

        emit LogMint(shares_, receiver_, amount0, amount1);
    }

    function burn(
        uint256 shares_,
        address receiver_
    ) external returns (uint256 amount0, uint256 amount1) {
        if (shares_ == 0) revert BurnZero();
        uint256 supply = totalSupply();
        if (shares_ > supply) revert BurnOverflow();

        uint256 proportion = FullMath.mulDiv(shares_, PIPS, supply);

        if (proportion == 0) revert CannotBurnProportionZero();
        if (receiver_ == address(0)) revert AddressZero("Receiver");

        _burn(msg.sender, shares_);

        (amount0, amount1) = _withdraw(receiver_, proportion);

        emit LogBurn(shares_, receiver_, amount0, amount1);
    }

    function name() public view override returns (string memory) {
        return _name;
    }

    function symbol() public view override returns (string memory) {
        return _symbol;
    }

    /// @notice function used to get the type of vault.
    function vaultType() external pure returns (bytes32) {
        return PUBLIC_TYPE;
    }

    // #region internal functions.

    function _deposit(
        uint256 proportion_
    ) internal nonReentrant returns (uint256 amount0, uint256 amount1) {
        /// @dev msg.sender should be the tokens provider

        bytes memory data = abi.encodeWithSelector(
            IArrakisLPModulePublic.deposit.selector,
            msg.sender,
            proportion_
        );

        bytes memory result = payable(address(module)).functionCallWithValue(
            data,
            msg.value
        );

        (amount0, amount1) = abi.decode(result, (uint256, uint256));
        emit LogDeposit(proportion_, amount0, amount1);
    }

    // #endregion internal functions.
}
