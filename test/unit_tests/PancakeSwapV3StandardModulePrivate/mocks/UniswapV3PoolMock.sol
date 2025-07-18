// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

contract UniswapV3PoolMock {
    address public token0;
    address public token1;
    uint160 public sqrtPriceX96;
    mapping(bytes32 => uint128) public _positions;
    mapping(bytes32 => bool) public activePositions;

    constructor(address _token0, address _token1) {
        token0 = _token0;
        token1 = _token1;
        sqrtPriceX96 = 1_356_476_084_642_877_807_665_053_548_195_417; // Default price
    }

    function setSqrtPriceX96(uint160 _sqrtPriceX96) external {
        sqrtPriceX96 = _sqrtPriceX96;
    }

    function slot0() external view returns (
        uint160 sqrtPriceX96_,
        int24 tick,
        uint16 observationIndex,
        uint16 observationCardinality,
        uint16 observationCardinalityNext,
        uint8 feeProtocol,
        bool unlocked
    ) {
        return (sqrtPriceX96, 0, 0, 0, 0, 0, true);
    }

    function mint(
        address recipient,
        int24 tickLower,
        int24 tickUpper,
        uint128 amount,
        bytes calldata
    ) external returns (uint256 amount0, uint256 amount1) {
        bytes32 positionId = keccak256(abi.encodePacked(recipient, tickLower, tickUpper));
        _positions[positionId] += amount;
        activePositions[positionId] = true;
        
        // Mock amounts based on liquidity
        amount0 = uint256(amount) * 1000e6 / 1e18;
        amount1 = uint256(amount) * 1e18 / 1e18;
        
        return (amount0, amount1);
    }

    function burn(
        int24 tickLower,
        int24 tickUpper,
        uint128 amount
    ) external returns (uint256 amount0, uint256 amount1) {
        bytes32 positionId = keccak256(abi.encodePacked(msg.sender, tickLower, tickUpper));
        require(_positions[positionId] >= amount, "Insufficient liquidity");
        _positions[positionId] -= amount;
        
        if (_positions[positionId] == 0) {
            activePositions[positionId] = false;
        }
        
        // Mock amounts based on liquidity
        amount0 = uint256(amount) * 1000e6 / 1e18;
        amount1 = uint256(amount) * 1e18 / 1e18;
        
        return (amount0, amount1);
    }

    function collect(
        address,
        int24,
        int24,
        uint128 amount0Requested,
        uint128 amount1Requested
    ) external returns (uint128 amount0, uint128 amount1) {
        // Mock collection amounts
        amount0 = amount0Requested;
        amount1 = amount1Requested;
        return (amount0, amount1);
    }

    function positions(bytes32 positionId) external view returns (
        uint128 liquidity,
        uint256 feeGrowthInside0LastX128,
        uint256 feeGrowthInside1LastX128,
        uint128 tokensOwed0,
        uint128 tokensOwed1
    ) {
        liquidity = _positions[positionId];
        return (liquidity, 0, 0, 0, 0);
    }

    function swap(
        address,
        bool zeroForOne,
        int256 amountSpecified,
        uint160,
        bytes calldata
    ) external returns (int256 amount0, int256 amount1) {
        // Mock swap amounts
        if (zeroForOne) {
            amount0 = amountSpecified;
            amount1 = -amountSpecified * 1e18 / 1000e6;
        } else {
            amount1 = amountSpecified;
            amount0 = -amountSpecified * 1000e6 / 1e18;
        }
        return (amount0, amount1);
    }

    function flash(
        address,
        uint256,
        uint256,
        bytes calldata
    ) external {
        // Mock flash loan
    }

    function increaseObservationCardinalityNext(uint16) external {
        // Mock function
    }

    function protocolFees() external view returns (uint128, uint128) {
        return (0, 0);
    }

    function setFeeProtocol(uint8, uint8) external {
        // Mock function
    }

    function collectProtocol(
        address,
        uint128,
        uint128
    ) external returns (uint128, uint128) {
        return (0, 0);
    }

    // Additional required functions
    function feeGrowthGlobal0X128() external view returns (uint256) {
        return 0;
    }

    function feeGrowthGlobal1X128() external view returns (uint256) {
        return 0;
    }

    function tickSpacing() external view returns (int24) {
        return 10;
    }

    function ticks(int24) external view returns (
        uint128 liquidityGross,
        int128 liquidityNet,
        uint256 feeGrowthOutside0X128,
        uint256 feeGrowthOutside1X128,
        int56 tickCumulativeOutside,
        uint160 secondsPerLiquidityOutsideX128,
        uint32 secondsOutside,
        bool initialized
    ) {
        return (0, 0, 0, 0, 0, 0, 0, false);
    }
} 