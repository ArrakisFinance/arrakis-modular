// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IPALMVaultNFT {
    // #region errors.

    error AddressZero();
    error ArrakisManagerAlreadySet();
    error NoArrakisManager();
    error NotOwner(address caller, address owner);
    error ValueDtMaxAmount(uint256 value, uint256 maxAmount);

    // #endregion errors.

    // #region events.

    event LogSetArrakisManager(address arrakisManager);
    event LogMint(
        bytes32 salt,
        address creator,
        address token0,
        address token1,
        address receiver,
        address module,
        uint256 tokenId,
        address vault
    );
    event LogDeposit(
        address owner,
        uint256 proportion,
        uint256 amount0,
        uint256 amount1
    );
    event LogWithdraw(
        address owner,
        uint256 proportion,
        uint256 amount0,
        uint256 amount1
    );

    event LogWhiteListedModules(address owner, address[] modules);
    event LogBlackListedModules(address owner, address[] modules);

    // #endregion events.

    // #region functions.

    function mint(
        bytes32 salt_,
        address token0_,
        address token1_,
        address receiver_,
        address module_
    ) external;

    /// @notice function used to deposit tokens or expand position inside the
    /// vault by owner.
    /// @param vault_ address of the owned meta vault where to deposit.
    /// @param proportion_ the proportion of position expansion.
    /// @param maxAmount0_ maximum amount of token0 wanted to deposit.
    /// @param maxAmount1_ maximum amount of token1 wanted to deposit.
    /// @return amount0 amount of token0 need to increase the position by proportion_;
    /// @return amount1 amount of token1 need to increase the position by proportion_;
    function deposit(
        address vault_,
        uint256 proportion_,
        uint256 maxAmount0_,
        uint256 maxAmount1_
    ) external payable returns (uint256 amount0, uint256 amount1);

    /// @notice function used to deposit tokens or expand position inside the
    /// vault by owner.
    /// @param vault_ address of the owned meta vault where to withdraw.
    /// @param proportion_ the proportion of position expansion.
    /// @return amount0 amount of token0 need to increase the position by proportion_;
    /// @return amount1 amount of token1 need to increase the position by proportion_;
    function withdraw(
        address vault_,
        uint256 proportion_,
        address receiver_
    ) external returns (uint256 amount0, uint256 amount1);

    /// @notice function used to whitelist modules that can used by manager.
    /// @param vault_ address of the owned meta vault where to whitelist modules.
    /// @param modules_ array of module addresses to be whitelisted.
    function whitelistModules(
        address vault_,
        address[] calldata modules_
    ) external;

    /// @notice function used to blacklist modules that can used by manager.
    /// @param vault_ address of the owned meta vault where to blacklist modules.
    /// @param modules_ array of module addresses to be blacklisted.
    function blacklistModules(
        address vault_,
        address[] calldata modules_
    ) external;

    // #endregion functions.

    // #region view/pure functions.

    function arrakisMetaVaultFactory() external view returns (address);

    function getTokenIdFromVaultAddr(
        address vault_
    ) external pure returns (uint256 tokenID);

    // #endregion view/pure functions.
}
