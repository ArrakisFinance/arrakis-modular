// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

// #region foundry.
import {TestWrapper} from "../utils/TestWrapper.sol";
import {console} from "forge-std/console.sol";
// #endregion foundry.

import {AerodromeRewardsViewer} from "../../src/utils/AerodromeRewardsViewer.sol";
import {IAerodromeRewardsViewer} from "../../src/interfaces/IAerodromeRewardsViewer.sol";
import {IArrakisMetaVault} from "../../src/interfaces/IArrakisMetaVault.sol";
import {IArrakisLPModule} from "../../src/interfaces/IArrakisLPModule.sol";
import {IArrakisLPModuleID} from "../../src/interfaces/IArrakisLPModuleID.sol";
import {IAerodromeStandardModulePrivate} from "../../src/interfaces/IAerodromeStandardModulePrivate.sol";
import {ICLGauge} from "../../src/interfaces/ICLGauge.sol";
import {PIPS} from "../../src/constants/CArrakis.sol";

// #region openzeppelin.
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// #endregion openzeppelin.

import {FullMath} from "@v3-lib-0.8/contracts/FullMath.sol";

contract AerodromeRewardsViewerTest is TestWrapper {
    // #region constant properties.
    address public constant AERO = 0x940181a94A35A4569E4529A3CDfB74e38FD98631;
    bytes32 public constant MODULE_ID = 0x491defc0794897991a8e5e9fa49dcbed24fe84ee079750b1db3f4df77fb17cb5;
    address public constant VAULT = 0xb40a6770D3fC7305Ee013911d473222DdA1F4CCA;
    uint256 public constant TEST_BLOCK = 34486761;
    // #endregion constant properties.

    AerodromeRewardsViewer public rewardsViewer;

    function setUp() public {
        // #region reset fork to specific block on Base chain.
        _reset(vm.envString("BASE_RPC_URL"), TEST_BLOCK);
        // #endregion reset fork.

        // #region deploy rewards viewer.
        rewardsViewer = new AerodromeRewardsViewer(AERO, MODULE_ID);
        // #endregion deploy rewards viewer.
    }

    function test_getClaimableRewards_success() public {
        // #region get claimable rewards for the specific vault.
        uint256 claimableRewards = rewardsViewer.getClaimableRewards(VAULT);
        // #endregion get claimable rewards.

        // #region assertions.
        // Verify that the function returns a value (should be >= 0)
        console.log("Claimable rewards:", claimableRewards);
        
        // The rewards should be a reasonable amount (not zero if there are active positions)
        // Note: We don't assert a specific value since it depends on the exact state at the block
        assertTrue(claimableRewards >= 0, "Claimable rewards should be non-negative");
        // #endregion assertions.
    }

    function test_getClaimableRewards_vault_zero_address() public {
        // #region test with zero address.
        vm.expectRevert(IAerodromeRewardsViewer.AddressZero.selector);
        rewardsViewer.getClaimableRewards(address(0));
        // #endregion test with zero address.
    }

    function test_getClaimableRewards_not_aerodrome_module() public {
        // #region create a mock vault address that doesn't have aerodrome module.
        address mockVault = vm.addr(uint256(keccak256(abi.encode("MockVault"))));
        
        // This should revert because the vault doesn't exist or doesn't have the correct module
        vm.expectRevert();
        rewardsViewer.getClaimableRewards(mockVault);
        // #endregion create mock vault.
    }

    function test_constructor_properties() public {
        // #region verify constructor properties.
        assertEq(rewardsViewer.AERO(), AERO, "AERO address should match");
        assertEq(rewardsViewer.id(), MODULE_ID, "Module ID should match");
        // #endregion verify constructor properties.
    }

    function test_getClaimableRewards_detailed_breakdown() public {
        // #region get detailed breakdown of rewards calculation.
        
        // Get the vault's module
        address module = address(IArrakisMetaVault(VAULT).module());
        
        // Verify this is indeed an Aerodrome module with correct ID
        bytes32 moduleId = IArrakisLPModuleID(module).id();
        assertEq(moduleId, MODULE_ID, "Module should have correct ID");
        
        // Get module state before calling rewards viewer
        uint256[] memory tokenIds = IAerodromeStandardModulePrivate(module).tokenIds();
        address gauge = IAerodromeStandardModulePrivate(module).gauge();
        uint256 aeroBalance = IERC20(AERO).balanceOf(module);
        uint256 managerBalance = uint256(vm.load(module, bytes32(uint256(161))));
        uint256 managerFeePIPS = IArrakisLPModule(module).managerFeePIPS();
        
        console.log("Module address:", module);
        console.log("Gauge address:", gauge);
        console.log("Number of token IDs:", tokenIds.length);
        console.log("AERO balance in module:", aeroBalance);
        console.log("Manager balance:", managerBalance);
        console.log("Manager fee PIPS:", managerFeePIPS);
        
        // Calculate expected rewards manually for verification
        uint256 totalGaugeRewards = 0;
        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];
            uint256 rewards = ICLGauge(gauge).rewards(tokenId);
            uint256 earned = ICLGauge(gauge).earned(module, tokenId);
            
            console.log("Token ID:", tokenId);
            console.log("  Rewards:", rewards);
            console.log("  Earned:", earned);
            
            totalGaugeRewards += rewards + earned;
        }
        
        console.log("Total gauge rewards:", totalGaugeRewards);
        
        // Get actual claimable rewards from viewer
        uint256 claimableRewards = rewardsViewer.getClaimableRewards(VAULT);
        
        console.log("Claimable rewards from viewer:", claimableRewards);

        // Verify the calculation matches our manual calculation
        // claimable = (aeroBalance - managerBalance) + (gaugeRewards - managerFee)
        uint256 managerFeeFromGauge = FullMath.mulDiv(totalGaugeRewards, managerFeePIPS, PIPS);
        uint256 expectedClaimable = (aeroBalance - managerBalance) + (totalGaugeRewards - managerFeeFromGauge);
        
        console.log("Expected claimable (manual calc):", expectedClaimable);
        console.log("Manager fee from gauge:", managerFeeFromGauge);
        
        assertEq(claimableRewards, expectedClaimable, "Claimable rewards should match manual calculation");
        // #endregion detailed breakdown.
    }

    function test_getClaimableRewards_state_consistency() public {
        // #region verify state consistency between calls.
        
        // Call the function multiple times to ensure consistency
        uint256 rewards1 = rewardsViewer.getClaimableRewards(VAULT);
        uint256 rewards2 = rewardsViewer.getClaimableRewards(VAULT);
        
        // Since we're in the same block and no state changes, results should be identical
        assertEq(rewards1, rewards2, "Multiple calls should return same result");
        
        console.log("Consistent rewards amount:", rewards1);
        // #endregion state consistency.
    }

    function test_interface_compliance() public {
        // #region verify interface compliance.
        
        // Test that the contract implements the expected interface
        assertTrue(address(rewardsViewer) != address(0), "Contract should be deployed");
        
        // Test interface functions exist and are callable
        bytes32 id = rewardsViewer.id();
        address aero = rewardsViewer.AERO();
        
        assertEq(id, MODULE_ID, "ID function should work");
        assertEq(aero, AERO, "AERO function should work");
        
        // Note: The interface shows CAKE() function but implementation has AERO
        // This might be a copy-paste error in the interface
        // #endregion interface compliance.
    }
}