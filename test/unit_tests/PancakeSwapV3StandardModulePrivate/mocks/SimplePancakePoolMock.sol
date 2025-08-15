// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

contract SimplePancakePoolMock {
    address public token0;
    address public token1;
    uint24 public fee;
    
    uint160 public sqrtPriceX96 = 79228162514264337593543950336; // sqrt(1) * 2^96
    int24 public tick;
    uint16 public observationIndex;
    uint16 public observationCardinality;
    uint16 public observationCardinalityNext;
    uint8 public feeProtocol;
    bool public unlocked = true;

    constructor(address _token0, address _token1, uint24 _fee) {
        token0 = _token0;
        token1 = _token1;
        fee = _fee;
    }

    function slot0()
        external
        view
        returns (
            uint160 _sqrtPriceX96,
            int24 _tick,
            uint16 _observationIndex,
            uint16 _observationCardinality,
            uint16 _observationCardinalityNext,
            uint8 _feeProtocol,
            bool _unlocked
        )
    {
        return (
            sqrtPriceX96,
            tick,
            observationIndex,
            observationCardinality,
            observationCardinalityNext,
            feeProtocol,
            unlocked
        );
    }

    function setSqrtPriceX96(uint160 _sqrtPriceX96) external {
        sqrtPriceX96 = _sqrtPriceX96;
    }

    function setTick(int24 _tick) external {
        tick = _tick;
    }
}