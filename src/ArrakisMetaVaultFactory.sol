// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {IArrakisMetaVaultFactory} from "./interfaces/IArrakisMetaVaultFactory.sol";
import {ArrakisMetaVaultToken} from "./ArrakisMetaVaultToken.sol";
import {ArrakisMetaVaultOwned} from "./ArrakisMetaVaultOwned.sol";

contract ArrakisMetaVaultFactory is IArrakisMetaVaultFactory {
    using EnumerableSet for EnumerableSet.AddressSet;

    EnumerableSet.AddressSet internal _tokenVaults;
    EnumerableSet.AddressSet internal _ownedVaults;

    /// @notice function used to deploy ERC20 token wrapped Arrakis
    /// Meta Vault.
    /// @param token0_ address of the first token of the token pair.
    /// @param token1_ address of the second token of the token pair.
    /// @param owner_ address of the owner of the vault.
    /// @param module_ address of the initial module that will be used
    /// by Meta Vault.
    /// @return vault address of the newly created Token Meta Vault.
    function deployTokenMetaVault(
        address token0_,
        address token1_,
        address owner_,
        address module_
    ) external returns (address vault) {
        string memory name = "Arrakis Modular Vault";
        string memory symbol = "AMV";

        try this.getTokenName(token0_, token1_) returns (string memory result) {
            name = result;
        } catch {} // solhint-disable-line no-empty-blocks

        try this.getTokenSymbol(token0_, token1_) returns (string memory result) {
            symbol = result;
        } catch {} // solhint-disable-line no-empty-blocks

        vault = address(
            new ArrakisMetaVaultToken(
                token0_,
                token1_,
                owner_,
                module_,
                name,
                symbol
            )
        );
        _tokenVaults.add(vault);

        emit LogTokenVaultCreation(msg.sender, vault);
    }

    /// @notice function used to deploy ERC20 owned Arrakis
    /// Meta Vault.
    /// @param token0_ address of the first token of the token pair.
    /// @param token1_ address of the second token of the token pair.
    /// @param owner_ address of the owner of the vault.
    /// @param module_ address of the initial module that will be used
    /// by Meta Vault.
    /// @return vault address of the newly created Owned Meta Vault.
    function deployOwnedMetaVault(
        address token0_,
        address token1_,
        address owner_,
        address module_
    ) external returns (address vault) {
        vault = address(
            new ArrakisMetaVaultOwned(token0_, token1_, owner_, module_)
        );
        _ownedVaults.add(vault);

        emit LogOwnedVaultCreation(msg.sender, vault);
    }

    // #region view/pure function.

    /// @notice get Arrakis Modular standard token name for two corresponding tokens.
    /// @param token0_ address of the first token.
    /// @param token1_ address of the second token.
    /// @return name name of the arrakis modular token vault.
    function getTokenName(
        address token0_,
        address token1_
    ) public view returns (string memory) {
        string memory symbol0 = IERC20Metadata(token0_).symbol();
        string memory symbol1 = IERC20Metadata(token1_).symbol();
        return _append("Arrakis Modular ", symbol0, "/", symbol1);
    }

    /// @notice get Arrakis Modular standard token symbol for two corresponding tokens.
    /// @param token0_ address of the first token.
    /// @param token1_ address of the second token.
    /// @return symbol symbol of the arrakis modular token vault.
    function getTokenSymbol(
        address token0_,
        address token1_
    ) public view returns (string memory) {
        string memory symbol0 = IERC20Metadata(token0_).symbol();
        string memory symbol1 = IERC20Metadata(token1_).symbol();
        return string(abi.encodePacked("AM", "/", symbol0, "/", symbol1));
    }

    /// @notice get a list of token vaults created by this factory
    /// @param startIndex_ start index
    /// @param endIndex_ end index
    /// @return vaults list of all created vaults.
    function tokenVaults(
        uint256 startIndex_,
        uint256 endIndex_
    ) external view returns (address[] memory) {
        if (startIndex_ >= endIndex_)
            revert StartIndexLtEndIndex(startIndex_, endIndex_);

        uint256 vaultsLength = numOfTokenVaults();
        if (endIndex_ > vaultsLength)
            revert EndIndexGtNbOfVaults(endIndex_, vaultsLength);

        address[] memory vs = new address[](endIndex_ - startIndex_);
        for (uint256 i = startIndex_; i < endIndex_; i++) {
            vs[i - startIndex_] = _tokenVaults.at(i);
        }

        return vs;
    }

    /// @notice numOfTokenVaults counts the total number of token vaults in existence
    /// @return result total number of vaults deployed
    function numOfTokenVaults() public view returns (uint256 result) {
        return _tokenVaults.length();
    }

    /// @notice get a list of owned vaults created by this factory
    /// @param startIndex_ start index
    /// @param endIndex_ end index
    /// @return vaults list of all created vaults.
    function ownedVaults(
        uint256 startIndex_,
        uint256 endIndex_
    ) external view returns (address[] memory) {
        if (startIndex_ >= endIndex_)
            revert StartIndexLtEndIndex(startIndex_, endIndex_);

        uint256 vaultsLength = numOfTokenVaults();
        if (endIndex_ > vaultsLength)
            revert EndIndexGtNbOfVaults(endIndex_, vaultsLength);

        address[] memory vs = new address[](endIndex_ - startIndex_);
        for (uint256 i = startIndex_; i < endIndex_; i++) {
            vs[i - startIndex_] = _ownedVaults.at(i);
        }

        return vs;
    }

    /// @notice numOfOwnedVaults counts the total number of owned vaults in existence
    /// @return result total number of vaults deployed
    function numOfOwnedVaults() public view returns (uint256 result) {
        return _ownedVaults.length();
    }

    // #endregion view/pure functions.

    // #region internal functions.

    function _append(
        string memory a_,
        string memory b_,
        string memory c_,
        string memory d_
    ) internal pure returns (string memory) {
        return string(abi.encodePacked(a_, b_, c_, d_));
    }

    // #endregion internal functions.
}
