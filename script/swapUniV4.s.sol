// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import {IPoolManager, PoolKey, IHooks} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";

bool constant zeroForOne = false;
int256 constant amountSpecified = 0;
uint160 constant sqrtPriceLimitX96 = 0;

address constant token0 = address(0);
address constant token1 = address(0);
uint24 constant fee = 0;
int24 constant tickSpacing = 0;
address constant hooks = address(0);


contract MovePriceScript is Script {
    function setUp() public {}

    function run() external {

        console.log(msg.sender);

        address poolManager = getPoolManager();
        
        vm.startBroadcast(msg.sender);

        IPoolManager.SwapParams memory swapParams = IPoolManager.SwapParams({
            zeroForOne: zeroForOne,
            amountSpecified: amountSpecified,
            sqrtPriceLimitX96: sqrtPriceLimitX96
        });

        // Define pool key
        PoolKey memory poolKey = PoolKey({
            currency0: Currency.wrap(token0), // Replace with token0 address
            currency1: Currency.wrap(token1), // Replace with token1 address
            fee: fee, // Example fee (0.3%)
            tickSpacing: tickSpacing,
            hooks: IHooks(hooks) // Replace with hooks address
        });

        IPoolManager(poolManager).swap(poolKey, swapParams, "");

        vm.stopBroadcast();
    }

    function getPoolManager() public view returns (address) {
        uint256 chainId = block.chainid;

        // mainnet
        if (chainId == 1) {
            return 0x000000000004444c5dc75cB358380D2e3dE08A90;
        }
        // polygon
        else if (chainId == 137) {
            return 0x67366782805870060151383F4BbFF9daB53e5cD6;
        }
        // optimism
        else if (chainId == 10) {
            return 0x9a13F98Cb987694C9F086b1F5eB990EeA8264Ec3;
        }
        // arbitrum
        else if (chainId == 42_161) {
            return 0x360E68faCcca8cA495c1B759Fd9EEe466db9FB32;
        }
        // sepolia
        else if (chainId == 11_155_111) {
            return 0xE03A1074c86CFeDd5C142C4F04F1a1536e203543;
        }
        // base
        else if (chainId == 8453) {
            return 0x498581fF718922c3f8e6A244956aF099B2652b2b;
        }
        // base sepolia
        else if (chainId == 84_531) {
            return 0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408;
        }
        // Ink
        else if (chainId == 57_073) {
            return 0x360E68faCcca8cA495c1B759Fd9EEe466db9FB32;
        }
        // binance
        else if (chainId == 56) {
            return 0x28e2Ea090877bF75740558f6BFB36A5ffeE9e9dF;
        }
        // Unichain
        else if (chainId == 130) {
            return 0x1F98400000000000000000000000000000000004;
        }
    }
}