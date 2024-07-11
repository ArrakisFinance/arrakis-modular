// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import {Deal} from "../structs/SBuilder.sol";

interface IBuilderHook {
    // #region errors.

    error AlreadyWhitelistedCollateral(address collateral);
    error NotAlreadyACollateral(address collateral);
    error NotACollateral();
    error NotValidSignature();
    error CannotReOpenThePool();
    error NotEnoughNativeCoinSent();
    error SqrtPriceZero();
    error FeeZero();
    error NotFeeFreeSwapper();
    error OnlyPoolManager();
    error OnlyPool();
    error NotRightDeal();
    error FeeFreeSwapHappened();
    error OnlyCaller();
    error NotEnoughFeeGenerated();
    error WrongFinalState();
    error WrongFinalSqrtPrice();

    // #endregion errors.

    // #region events.

    event LogWhitelistCollateral(address[] collaterals);
    event LogBlacklistCollateral(address[] collaterals);
    event OpenPool(Deal deal, bytes signature);
    event ClosePool(Deal deal, address receiver);
    event GetTokens(address token, address receiver);

    // #endregion events.

    function openPool(
        Deal calldata deal_,
        bytes calldata signature_
    ) external payable;

    function closePool(
        Deal calldata deal_,
        address receiver_
    ) external;

    function whitelistCollaterals(address[] calldata collaterals_)
        external;
    function blacklistCollaterals(address[] calldata collaterals_)
        external;

    function getTokens(address token_, address receiver_)
        external
        returns (uint256 amount);

    // #region view functions.

    function signer() external view returns (address);

    function collaterals() external view returns (address[] memory);

    // #endregion view functions.
}
