// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {ArrakisMetaLPToken} from "../src/ArrakisMetaLPToken.sol";
import {ArrakisMetaLP} from "../src/ArrakisMetaLP.sol";
import {AaveV3LendModule} from "../src/modules/AaveV3LendModule.sol";
import {UniV2Module} from "../src/modules/UniV2Module.sol";
import {IERC20} from "../src/interfaces/IERC20.sol";
import {IATokenExt} from "../src/interfaces/IATokenExt.sol";
import {IUniswapV2Factory} from "v2-core/interfaces/IUniswapV2Factory.sol";

contract ArrakisModularTest is Test {
    ArrakisMetaLPToken public token;
    ArrakisMetaLP public vault;
    AaveV3LendModule public aaveV3Module;
    UniV2Module public uniV2Module;
    IERC20 public token0;
    IERC20 public token1;

    function setUp() public {
        token0 = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
        token1 = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
        vault = new ArrakisMetaLP(
            address(token0),
            address(token1),
            address(this),
            10**9,
            1 ether
        );

        aaveV3Module = new AaveV3LendModule(
            IATokenExt(0x98C23E9d8f34FEFb1B7BD6a91B7FF122F4e16F5c),
            IATokenExt(0x4d5F47FA6A74757f35C14fD3a6Ef8E3C9BC514E8),
            address(vault),
            10**9,
            1 ether
        );

        uniV2Module = new UniV2Module(
            IUniswapV2Factory(0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f),
            address(token0),
            address(token1),
            address(vault),
            10**14
        );

        vault.addModule(address(uniV2Module));
        vault.addModule(address(aaveV3Module));
        vault.setManager(address(this));

        token = new ArrakisMetaLPToken(
            vault,
            address(0),
            "TEST TOKEN",
            "TT"
        );

        vault.transferOwnership(address(token));

        vm.prank(0xDa9CE944a37d218c3302F6B82a094844C6ECEb17);
        token0.transfer(address(this), 10**13);
        vm.prank(0x57757E3D981446D585Af0D9Ae4d7DF6D64647806);
        token1.transfer(address(this), 1000 ether);

        token0.approve(address(token), type(uint).max);
        token1.approve(address(token), type(uint).max);
    }

    function test_mint() public {
        uint256 bal0 = token0.balanceOf(address(this));
        uint256 bal1 = token1.balanceOf(address(this));

        assertEq(bal0, 10**13);
        assertEq(bal1, 1000 ether);

        (uint256 init0, uint256 init1) = vault.getInits();
        assertGt(init0, 2*10**9);
        assertGt(init1, 2 ether);
        uint256 balanceLPBefore = token.balanceOf(address(this));
        token.mint(1 ether, address(this));

        uint256 bal0After = token0.balanceOf(address(this));
        uint256 bal1After = token1.balanceOf(address(this));

        uint256 balanceLPAfter = token.balanceOf(address(this));

        assertEq(bal0-bal0After, init0);
        assertEq(bal1-bal1After, init1);

        assertEq(balanceLPBefore, 0);
        assertEq(balanceLPAfter, 1 ether);

        (uint256 a0, uint256 a1) = vault.totalUnderlying();

        assertGt(init0, a0);
        assertGt(init1, a1);
        assertEq(init0-1, a0);
        assertGt(init1/10**10, init1-a1);

        uint256 bal0Vault = token0.balanceOf(address(vault));
        uint256 bal1Vault = token1.balanceOf(address(vault));

        assertEq(bal0Vault, 10**9);
        assertEq(bal1Vault, 1 ether);
    }

    function test_mint_gas() public {
        token.mint(1 ether, address(this));
    }
}
