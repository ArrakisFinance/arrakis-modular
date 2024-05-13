// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {IArrakisMetaVaultPublic} from
    "./interfaces/IArrakisMetaVaultPublic.sol";
import {IArrakisLPModulePublic} from
    "./interfaces/IArrakisLPModulePublic.sol";
import {
    ArrakisMetaVault, BASE
} from "./abstracts/ArrakisMetaVault.sol";
import {MINIMUM_LIQUIDITY} from "./constants/CArrakis.sol";

import {FullMath} from "@v3-lib-0.8/contracts/FullMath.sol";

import {Address} from "@openzeppelin/contracts/utils/Address.sol";

import {Ownable} from "@solady/contracts/auth/Ownable.sol";
import {ERC20} from "@solady/contracts/tokens/ERC20.sol";

contract ArrakisMetaVaultPublic is
    IArrakisMetaVaultPublic,
    ArrakisMetaVault,
    Ownable,
    ERC20
{
    using Address for address payable;

    string internal _name;
    string internal _symbol;

    constructor(
        address owner_,
        string memory name_,
        string memory symbol_,
        address moduleRegistry_,
        address manager_,
        address token0_,
        address token1_
    ) ArrakisMetaVault(moduleRegistry_, manager_, token0_, token1_) {
        if (owner_ == address(0)) revert AddressZero("Owner");
        _initializeOwner(owner_);
        _name = name_;
        _symbol = symbol_;
    }

    /// @notice function used to mint share of the vault position
    /// @param shares_ amount representing the part of the position owned by receiver.
    /// @param receiver_ address where share token will be sent.
    /// @return amount0 amount of token0 deposited.
    /// @return amount1 amount of token1 deposited.
    function mint(
        uint256 shares_,
        address receiver_
    ) external payable returns (uint256 amount0, uint256 amount1) {
        if (shares_ == 0) revert MintZero();
        uint256 supply = totalSupply();

        uint256 proportion = FullMath.mulDivRoundingUp(
            shares_, BASE, supply > 0 ? supply : 1 ether
        );

        if (receiver_ == address(0)) revert AddressZero("Receiver");

        if (supply == 0) {
            _mint(address(0), MINIMUM_LIQUIDITY);
            shares_ = shares_ - MINIMUM_LIQUIDITY;
        }

        _mint(receiver_, shares_);

        (amount0, amount1) = _deposit(proportion);

        emit LogMint(shares_, receiver_, amount0, amount1);
    }

    /// @notice function used to burn share of the vault position.
    /// @param shares_ amount of share that will be burn.
    /// @param receiver_ address where underlying tokens will be sent.
    /// @return amount0 amount of token0 withdrawn.
    /// @return amount1 amount of token1 withdrawn.
    function burn(
        uint256 shares_,
        address receiver_
    ) external returns (uint256 amount0, uint256 amount1) {
        if (shares_ == 0) revert BurnZero();
        uint256 supply = totalSupply();
        if (shares_ > supply) revert BurnOverflow();

        uint256 proportion = FullMath.mulDiv(shares_, BASE, supply);

        if (receiver_ == address(0)) revert AddressZero("Receiver");

        _burn(msg.sender, shares_);

        (amount0, amount1) = _withdraw(receiver_, proportion);

        emit LogBurn(shares_, receiver_, amount0, amount1);
    }

    // #region Ownable functions.

    /// @dev override transfer of ownership, to make it not possible.
    function transferOwnership(address) public payable override {
        revert NotImplemented();
    }

    /// @dev override transfer of ownership, to make it not possible.
    function renounceOwnership() public payable override {
        revert NotImplemented();
    }

    /// @dev override transfer of ownership, to make it not possible.
    function completeOwnershipHandover(address)
        public
        payable
        override
    {
        revert NotImplemented();
    }

    // #endregion Ownable functions.

    /// @notice function used to get the name of the LP token.
    /// @return name string value containing the name.
    function name() public view override returns (string memory) {
        return _name;
    }

    /// @notice function used to get the symbol of the LP token.
    /// @return symbol string value containing the symbol.
    function symbol() public view override returns (string memory) {
        return _symbol;
    }

    // #region internal functions.

    function _deposit(uint256 proportion_)
        internal
        nonReentrant
        returns (uint256 amount0, uint256 amount1)
    {
        /// @dev msg.sender should be the tokens provider

        bytes memory data = abi.encodeWithSelector(
            IArrakisLPModulePublic.deposit.selector,
            msg.sender,
            proportion_
        );

        bytes memory result = payable(address(module))
            .functionCallWithValue(data, msg.value);

        (amount0, amount1) = abi.decode(result, (uint256, uint256));
    }

    function _onlyOwnerCheck() internal view override {
        if (msg.sender != owner()) revert OnlyOwner();
    }

    // #endregion internal functions.
}
