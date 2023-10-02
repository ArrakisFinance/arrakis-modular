// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {IArrakisMetaToken} from "./interfaces/IArrakisMetaToken.sol";
import {ERC20} from "solady/src/tokens/ERC20.sol";
import {ArrakisMetaVault} from "./ArrakisMetaVault.sol";
import {FullMath} from "v3-lib-0.8/FullMath.sol";

error NotImplemented();
error MintZero();
error BurnZero();
error BurnOverflow();

contract ArrakisMetaVaultToken is IArrakisMetaToken, ArrakisMetaVault, ERC20 {
    string internal _name;
    string internal _symbol;

    constructor(
        address token0_,
        address token1_,
        address owner_,
        uint256 init0_,
        uint256 init1_,
        address module_,
        string memory name_,
        string memory symbol_
    ) ArrakisMetaVault(token0_, token1_, owner_, init0_, init1_, module_) {
        _name = name_;
        _symbol = symbol_;
    }

    function deposit(
        uint256
    ) external override returns (uint256, uint256) {
        revert NotImplemented();
    }

    function withdraw(
        uint256,
        address
    ) external override returns (uint256, uint256) {
        revert NotImplemented();
    }

    function burn(
        uint256 shares_,
        address receiver_
    ) external returns (uint256 amount0, uint256 amount1) {
        if (shares_ == 0) revert BurnZero();
        uint256 supply = totalSupply();
        if (shares_ > supply) revert BurnOverflow();

        uint256 proportion = FullMath.mulDiv(shares_, _PIPS, supply);

        _burn(msg.sender, shares_);

        (amount0, amount1) = _withdrawAndSend(proportion, receiver_);

        emit LogBurn(shares_, receiver_, amount0, amount1);
    }

    function mint(
        uint256 shares_,
        address receiver_
    ) external returns (uint256 amount0, uint256 amount1) {
        if (shares_ == 0) revert MintZero();
        uint256 supply = totalSupply();

        uint256 proportion = FullMath.mulDiv(
            shares_,
            _PIPS,
            supply > 0 ? supply : 1 ether
        );
        _tokenSender = msg.sender;

        _mint(receiver_, shares_);

        (amount0, amount1) = _deposit(proportion);

        emit LogMint(shares_, receiver_, amount0, amount1);
    }

    function name() public view override returns (string memory) {
        return _name;
    }

    function symbol() public view override returns (string memory) {
        return _symbol;
    }
}
