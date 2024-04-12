// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

contract OracleWrapperMock {
    uint256 internal _price0;
    uint256 internal _price1;

    function setPrice0(uint256 price_) external {
        _price0 = price_;
    }

    function setPrice1(uint256 price_) external {
        _price1 = price_;
    }

    function getPrice0() external view returns (uint256) {
        return _price0;
    }

    function getPrice1() external view returns (uint256) {
        return _price1;
    }
}
