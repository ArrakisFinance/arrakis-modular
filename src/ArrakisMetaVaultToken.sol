// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IArrakisMetaToken} from "./interfaces/IArrakisMetaToken.sol";
import {ERC20} from "@solady/contracts/tokens/ERC20.sol";
import {ArrakisMetaVault, PIPS} from "./ArrakisMetaVault.sol";
import {FullMath} from "@uniswap/v4-core/src/libraries/FullMath.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ArrakisMetaVaultToken is IArrakisMetaToken, ArrakisMetaVault, ERC20 {
    string internal _name;
    string internal _symbol;

    constructor(
        address token0_,
        address token1_,
        address owner_,
        address module_,
        string memory name_,
        string memory symbol_
    ) ArrakisMetaVault(token0_, token1_, owner_, module_) {
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
}
