// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

// #region foundry.
import {console} from "forge-std/console.sol";
import {TestWrapper} from "../../utils/TestWrapper.sol";
// #endregion foundry.

import {HOTOracleWrapper} from
    "../../../src/modules/HOTOracleWrapper.sol";
import {IOracleWrapper} from
    "../../../src/interfaces/IOracleWrapper.sol";

import {FullMath} from "@v3-lib-0.8/contracts/FullMath.sol";

// #region mocks.

import {HOTOracleMock} from "./mocks/HOTOracleMock.sol";
import {HOTOracleMock2} from "./mocks/HOTOracleMock2.sol";

// #endregion mocks.

contract HOTOracleWrapperTest is TestWrapper {
    HOTOracleWrapper public oracleWrapper;

    function setUp() public {}

    // #region test constructor.

    function testConstructorOracleAddressZero() public {
        vm.expectRevert(IOracleWrapper.AddressZero.selector);

        oracleWrapper = new HOTOracleWrapper(address(0), 6, 18);
    }

    function testConstructorDecimalsToken0Zero() public {
        address oracle =
            vm.addr(uint256(keccak256(abi.encode("Oracle"))));
        vm.expectRevert(IOracleWrapper.DecimalsToken0Zero.selector);

        oracleWrapper = new HOTOracleWrapper(oracle, 0, 18);
    }

    function testConstructorDecimalsToken1Zero() public {
        address oracle =
            vm.addr(uint256(keccak256(abi.encode("Oracle"))));
        vm.expectRevert(IOracleWrapper.DecimalsToken1Zero.selector);

        oracleWrapper = new HOTOracleWrapper(oracle, 6, 0);
    }

    function testConstructor() public {
        address oracle =
            vm.addr(uint256(keccak256(abi.encode("Oracle"))));

        oracleWrapper = new HOTOracleWrapper(oracle, 6, 18);

        assertEq(oracleWrapper.decimals0(), 6);
        assertEq(oracleWrapper.decimals1(), 18);
        assertEq(address(oracleWrapper.oracle()), oracle);
    }

    // #endregion test constructor.

    // #region test getPrice0 and getPrice1.

    function testGetPrice0AndPrice1PriceX96LtMaxUint128() public {
        uint8 decimals0 = 6;
        uint8 decimals1 = 18;
        // #region create oracleWrapper.

        HOTOracleMock oracle = new HOTOracleMock();
        uint256 priceX96 = oracle.getSqrtOraclePriceX96();

        // #endregion create oracleWrapper.

        oracleWrapper = new HOTOracleWrapper(
            address(oracle), decimals0, decimals1
        );

        // #region compute expected prices.

        uint256 expectedPrice0 = FullMath.mulDiv(
            priceX96 * priceX96, 10 ** decimals0, 2 ** 192
        );

        uint256 expectedPrice1 = FullMath.mulDiv(
            2 ** 192, 10 ** decimals1, priceX96 * priceX96
        );

        // #endregion compute expected prices.

        uint256 price0 = oracleWrapper.getPrice0();
        uint256 price1 = oracleWrapper.getPrice1();

        assertEq(expectedPrice0, price0);
        assertEq(expectedPrice1, price1);
    }

    function testGetPrice0AndPrice1PriceX96GtMaxUint128() public {
        uint8 decimals0 = 6;
        uint8 decimals1 = 18;
        // #region create oracleWrapper.

        HOTOracleMock2 oracle = new HOTOracleMock2();
        uint256 priceX96 = oracle.getSqrtOraclePriceX96();

        // #endregion create oracleWrapper.

        oracleWrapper = new HOTOracleWrapper(
            address(oracle), decimals0, decimals1
        );

        // #region compute expected prices.

        uint256 expectedPrice0 = FullMath.mulDiv(
            FullMath.mulDiv(priceX96, priceX96, 1 << 64),
            10 ** decimals0,
            1 << 128
        );

        uint256 expectedPrice1 = FullMath.mulDiv(
            1 << 128,
            10 ** decimals1,
            FullMath.mulDiv(priceX96, priceX96, 1 << 64)
        );

        // #endregion compute expected prices.

        uint256 price0 = oracleWrapper.getPrice0();
        uint256 price1 = oracleWrapper.getPrice1();

        assertEq(expectedPrice0, price0);
        assertEq(expectedPrice1, price1);
    }

    // #endregion test getPrice0 and getPrice1.
}
