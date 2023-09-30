// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Test} from "forge-std/Test.sol";
import {ArrakisMetaLPToken} from "../src/ArrakisMetaLPToken.sol";
import {ArrakisMetaLP} from "../src/ArrakisMetaLP.sol";
import {AaveV3LendModule} from "../src/modules/AaveV3LendModule.sol";
import {UniV2Module} from "../src/modules/UniV2Module.sol";
import {IERC20} from "../src/interfaces/IERC20.sol";
import {IATokenExt} from "../src/interfaces/IATokenExt.sol";
import {IUniswapV2Factory} from "v2-core/interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Pair} from "v2-core/interfaces/IUniswapV2Pair.sol";
import {console} from "forge-std/console.sol";

contract ArrakisModularTest is Test {
    ArrakisMetaLPToken public lpTokenUni;
    ArrakisMetaLPToken public lpTokenUniAave;
    ArrakisMetaLP public vaultUni;
    ArrakisMetaLP public vaultUniAave;
    AaveV3LendModule public aaveV3Module;
    UniV2Module public uniV2Module;
    UniV2Module public uniV2Module2;
    IERC20 public token0;
    IERC20 public token1;
    IUniswapV2Pair public pair;

    function setUp() public {
        token0 = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
        token1 = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
        vaultUniAave = new ArrakisMetaLP(
            address(token0),
            address(token1),
            address(this),
            10**9,
            1 ether
        );

        aaveV3Module = new AaveV3LendModule(
            IATokenExt(0x98C23E9d8f34FEFb1B7BD6a91B7FF122F4e16F5c),
            IATokenExt(0x4d5F47FA6A74757f35C14fD3a6Ef8E3C9BC514E8),
            address(vaultUniAave),
            10**9,
            1 ether
        );

        uniV2Module = new UniV2Module(
            IUniswapV2Factory(0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f),
            address(token0),
            address(token1),
            address(vaultUniAave),
            10**15
        );

        vaultUniAave.addModule(address(uniV2Module));
        vaultUniAave.addModule(address(aaveV3Module));
        vaultUniAave.setManager(address(this));

        lpTokenUniAave = new ArrakisMetaLPToken(
            vaultUniAave,
            address(0),
            "TEST TOKEN",
            "TT"
        );

        vaultUniAave.transferOwnership(address(lpTokenUniAave));

        vm.prank(0xDa9CE944a37d218c3302F6B82a094844C6ECEb17);
        token0.transfer(address(this), 10**13);
        vm.prank(0x57757E3D981446D585Af0D9Ae4d7DF6D64647806);
        token1.transfer(address(this), 1000 ether);

        token0.approve(address(lpTokenUniAave), type(uint).max);
        token1.approve(address(lpTokenUniAave), type(uint).max);

        vaultUni = new ArrakisMetaLP(
            address(token0),
            address(token1),
            address(this),
            10**9,
            1 ether
        );
        uniV2Module2 = new UniV2Module(
            IUniswapV2Factory(0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f),
            address(token0),
            address(token1),
            address(vaultUni),
            10**15
        );
        vaultUni.addModule(address(uniV2Module2));
        vaultUni.setManager(address(this));
        lpTokenUni = new ArrakisMetaLPToken(
            vaultUni,
            address(0),
            "TEST TOKEN 2",
            "TT2"
        );
        vaultUni.transferOwnership(address(lpTokenUni));
        token0.approve(address(lpTokenUni), type(uint).max);
        token1.approve(address(lpTokenUni), type(uint).max);

        pair = IUniswapV2Pair(
            IUniswapV2Factory(0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f).getPair(address(token0), address(token1))
        );
    }

    function test_mint_burn() public {
        uint256 bal0 = token0.balanceOf(address(this));
        uint256 bal1 = token1.balanceOf(address(this));

        assertEq(bal0, 10**13);
        assertEq(bal1, 1000 ether);

        (uint256 init0, uint256 init1) = vaultUniAave.getInits();
        assertGt(init0, 2*10**9);
        assertGt(init1, 2 ether);

        uint256 balanceLPBefore = lpTokenUniAave.balanceOf(address(this));

        lpTokenUniAave.mint(1 ether, address(this));

        uint256 bal0After = token0.balanceOf(address(this));
        uint256 bal1After = token1.balanceOf(address(this));
        uint256 balanceLPAfter = lpTokenUniAave.balanceOf(address(this));
        
        assertEq(bal0-bal0After, init0);
        assertEq(bal1-bal1After, init1);
        assertEq(balanceLPBefore, 0);
        assertEq(balanceLPAfter, 1 ether);

        (uint256 a0, uint256 a1) = vaultUniAave.totalUnderlying();

        assertGe(init0, a0);
        assertGe(init1, a1);
        assertGt(init0/10**8, init0-a0);
        assertGt(init1/10**8, init1-a1);

        uint256 bal0Vault = token0.balanceOf(address(vaultUniAave));
        uint256 bal1Vault = token1.balanceOf(address(vaultUniAave));

        assertEq(bal0Vault, 10**9);
        assertEq(bal1Vault, 1 ether);

        uint256 bal0UniMod = token0.balanceOf(address(uniV2Module));
        uint256 bal1UniMod = token1.balanceOf(address(uniV2Module));
        uint256 bal0AaveMod = token0.balanceOf(address(aaveV3Module));
        uint256 bal1AaveMod = token1.balanceOf(address(aaveV3Module));

        assertEq(bal0AaveMod, 0);
        assertEq(bal1AaveMod, 0);
        assertEq(bal0UniMod, 0);
        assertEq(bal1UniMod, 0);

        lpTokenUniAave.burn(1 ether, address(this));

        uint256 bal0Final = token0.balanceOf(address(this));
        uint256 bal1Final = token1.balanceOf(address(this));
        uint256 balanceLPFinal = lpTokenUniAave.balanceOf(address(this));

        assertEq(bal0Final-bal0After, a0);
        assertEq(bal1Final-bal1After, a1);
        assertEq(balanceLPFinal, 0);
    }

    function test_rebalance() public {
        uint256 bal0Vault;
        uint256 bal1Vault;
        uint256 totalUnderlyingBefore0;
        uint256 totalUnderlyingBefore1;
        {
            uint256 bal0 = token0.balanceOf(address(this));
            uint256 bal1 = token1.balanceOf(address(this));

            assertEq(bal0, 10**13);
            assertEq(bal1, 1000 ether);

            (uint256 init0, uint256 init1) = vaultUniAave.getInits();
            assertGt(init0, 2*10**9);
            assertGt(init1, 2 ether);

            uint256 balanceLPBefore = lpTokenUniAave.balanceOf(address(this));

            lpTokenUniAave.mint(1 ether, address(this));

            uint256 bal0After = token0.balanceOf(address(this));
            uint256 bal1After = token1.balanceOf(address(this));
            uint256 balanceLPAfter = lpTokenUniAave.balanceOf(address(this));
            
            assertEq(bal0-bal0After, init0);
            assertEq(bal1-bal1After, init1);
            assertEq(balanceLPBefore, 0);
            assertEq(balanceLPAfter, 1 ether);

            (uint256 a0, uint256 a1) = vaultUniAave.totalUnderlying();

            assertGe(init0, a0);
            assertGe(init1, a1);
            assertEq(init0-1, a0);
            assertGt(100000, init1-a1);

            bal0Vault = token0.balanceOf(address(vaultUniAave));
            bal1Vault = token1.balanceOf(address(vaultUniAave));

            assertEq(bal0Vault, 10**9);
            assertEq(bal1Vault, 1 ether);

            uint256 bal0UniMod = token0.balanceOf(address(uniV2Module));
            uint256 bal1UniMod = token1.balanceOf(address(uniV2Module));
            uint256 bal0AaveMod = token0.balanceOf(address(aaveV3Module));
            uint256 bal1AaveMod = token1.balanceOf(address(aaveV3Module));

            assertEq(bal0AaveMod, 0);
            assertEq(bal1AaveMod, 0);
            assertEq(bal0UniMod, 0);
            assertEq(bal1UniMod, 0);

            totalUnderlyingBefore0 = a0;
            totalUnderlyingBefore1 = a1;
        }

        {
            (uint256 aaveBal0, uint256 aaveBal1) = aaveV3Module.totalUnderlying();

            uint256 leftover0 = aaveBal0+bal0Vault;
            uint256 leftover1 = aaveBal1+bal1Vault;

            (uint256 r0, uint256 r1,) = pair.getReserves();
            uint256 supply = pair.totalSupply();
            bool check = leftover0*r1/r0 > leftover1;
            uint256 deposit0;
            uint256 deposit1;
            if (check) {
                deposit0 = leftover1*r0/r1;
                deposit1 = deposit0*r1/r0;
            } else {
                deposit1 = leftover0*r1/r0;
                deposit0 = deposit1*r0/r1;
            }
            assertGe(leftover0, deposit0);
            assertGe(leftover1, deposit1);

            uint256 liquidityToDeposit = supply*deposit0/r0;

            bytes memory payloadAave = abi.encodeWithSelector(
                aaveV3Module.take.selector,
                aaveBal0,
                aaveBal1
            );

            bytes memory payloadUni = abi.encodeWithSelector(
                uniV2Module.depositLiquidity.selector,
                liquidityToDeposit
            );

            bytes[] memory payloads = new bytes[](2);
            address[] memory targets = new address[](2);

            targets[0] = address(aaveV3Module);
            targets[1] = address(uniV2Module);
            payloads[0] = payloadAave;
            payloads[1] = payloadUni;

            vaultUniAave.rebalance(targets, payloads);
        }
        
        (uint256 check0, uint256 check1) = aaveV3Module.totalUnderlying();
        assertEq(check0, 0);
        assertEq(check1, 0);

        (check0, check1) = vaultUniAave.totalUnderlying();

        assertGe(totalUnderlyingBefore0, check0);
        assertGe(totalUnderlyingBefore1, check1);
        assertGt(totalUnderlyingBefore0/10**8, totalUnderlyingBefore0-check0);
        assertGt(totalUnderlyingBefore1/10**8, totalUnderlyingBefore1-check1);

        uint256 bal0VaultEnd = token0.balanceOf(address(vaultUniAave));
        uint256 bal1VaultEnd = token1.balanceOf(address(vaultUniAave));

        assertGt(bal0Vault, bal0VaultEnd);
        assertGt(bal1Vault, bal1VaultEnd);
    }

    function test_uni_mint_GAS() public {
        lpTokenUni.mint(1 ether, address(this));
    }

    function test_uni_aave_mint_GAS() public {
        lpTokenUniAave.mint(1 ether, address(this));
    }
}
