// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "solady/src/tokens/ERC20.sol";
import {SafeCastLib} from "solady/src/utils/SafeCastLib.sol";
import {FullMath} from "v3-lib-0.8/FullMath.sol";
import {IArrakisMetaLP} from "./interfaces/IArrakisMetaLP.sol";

contract ArrakisMetaLPToken is ERC20 {
    using SafeCastLib for uint256;

    error BurnZero();
    error MintZero();
    error OnlyMinter();
    error BurnOverflow();

    uint24 internal constant _PIPS = 1000000;

    IArrakisMetaLP public immutable vault;
    address public immutable minter;
    address public immutable token0;
    address public immutable token1;

    string internal _name;
    string internal _symbol;

    constructor (
        IArrakisMetaLP _vault,
        address _minter,
        string memory _name_,
        string memory _symbol_
    ) {
        vault = _vault;
        token0 = _vault.token0();
        token1 = _vault.token1();
        minter = _minter;
        _name = _name_;
        _symbol = _symbol_;
    }

    function mint(uint256 shares, address receiver) external returns (uint256 amount0, uint256 amount1) {
        if (shares == 0) revert MintZero();
        if (minter != address(0) && msg.sender != minter) revert OnlyMinter();
        uint256 supply = totalSupply();

        (uint256 current0, uint256 current1) = supply > 0 ? vault.totalUnderlying() : vault.getInits();

        amount0 = FullMath.mulDiv(current0, shares, supply > 0 ? supply : 1 ether);
        amount1 = FullMath.mulDiv(current1, shares, supply > 0 ? supply : 1 ether);

        if (amount0 > 0) IERC20(token0).transferFrom(msg.sender, address(vault), amount0);
        if (amount1 > 0) IERC20(token1).transferFrom(msg.sender, address(vault), amount1);
        uint256 proportion = FullMath.mulDiv(shares, _PIPS, supply > 0 ? supply : 1 ether);
        vault.deposit(proportion);

        _mint(receiver, shares);
    }

    function burn(uint256 shares, address receiver) external returns (uint256 amount0, uint256 amount1) {
        if (shares == 0) revert BurnZero();
        uint256 supply = totalSupply();
        if (shares > supply) revert BurnOverflow();
        
        uint24 proportion = FullMath.mulDiv(shares, _PIPS, supply).toUint24();

        (amount0, amount1) = vault.withdraw(proportion, receiver);

        _burn(msg.sender, shares);
    }

    function name() public view override returns (string memory) {
        return _name;
    }

    function symbol() public view override returns (string memory) {
        return _symbol;
    }

    function totalUnderlying() external view returns (uint256 amount0, uint256 amount1) {
        return vault.totalUnderlying();
    }

    function totalUnderlyingAtPrice(uint256 priceX96) external view returns (uint256 amount0, uint256 amount1) {
        return vault.totalUnderlyingAtPrice(priceX96);
    }
}