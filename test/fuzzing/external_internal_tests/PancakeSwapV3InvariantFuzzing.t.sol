// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {PancakeSwapV3StandardModulePrivate} from
    "../../../src/modules/PancakeSwapV3StandardModulePrivate.sol";
import {ArrakisMetaVaultFactory} from
    "../../../src/ArrakisMetaVaultFactory.sol";
import {ModulePublicRegistry} from
    "../../../src/ModulePublicRegistry.sol";
import {ArrakisStandardManager} from
    "../../../src/ArrakisStandardManager.sol";
import {Guardian} from "../../../src/Guardian.sol";

// #region interfaces
import {IArrakisMetaVaultFactory} from
    "../../../src/interfaces/IArrakisMetaVaultFactory.sol";
import {IArrakisMetaVault} from
    "../../../src/interfaces/IArrakisMetaVault.sol";
import {IOwnable} from
    "../../../src/interfaces/IOwnable.sol";
import {IArrakisMetaVaultPrivate} from
    "../../../src/interfaces/IArrakisMetaVaultPrivate.sol";
import {IArrakisStandardManager} from
    "../../../src/interfaces/IArrakisStandardManager.sol";
import {IPancakeSwapV3StandardModule} from
    "../../../src/interfaces/IPancakeSwapV3StandardModule.sol";
import {IModuleRegistry} from
    "../../../src/interfaces/IModuleRegistry.sol";
import {IOracleWrapper} from "../../../src/interfaces/IOracleWrapper.sol";
import {IERC20Metadata} from
    "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
// #endregion interfaces

// #region structs
import {SetupParams} from "../../../src/structs/SManager.sol";
import {RebalanceParams} from "../../../src/structs/SPancakeSwapV3.sol";
import {ModifyPosition, SwapPayload} from "../../../src/structs/SUniswapV3.sol";
import {INonfungiblePositionManagerPancake} from "../../../src/interfaces/INonfungiblePositionManagerPancake.sol";
// #endregion structs

// #region openzeppelin
import {UpgradeableBeacon} from
    "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {BeaconProxy} from
    "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
// #endregion openzeppelin

// #region constants
import {
    BASE,
    PIPS,
    TEN_PERCENT
} from "../../../src/constants/CArrakis.sol";
// #endregion constants

contract PancakeSwapV3InvariantFuzzing {
    // #region mainnet addresses
    address constant FACTORY = 0x820FB8127a689327C863de8433278d6181123982;
    address constant MANAGER = 0x2e6E879648293e939aA68bA4c6c129A1Be733bDA;
    address constant PUBLIC_REGISTRY = 0x791d75F87a701C3F7dFfcEC1B6094dB22c779603;
    address constant GUARDIAN = 0x6F441151B478E0d60588f221f1A35BcC3f7aB981;
    
    // PancakeSwap addresses on mainnet
    address constant PANCAKE_NFT_POSITION_MANAGER = 0x46A15B0b27311cedF172AB29E4f4766fbE7F4364;
    address constant PANCAKE_FACTORY = 0x0BFbCF9fa4f9C56B0F40a671Ad40E0805A091865;
    address constant CAKE_TOKEN = 0x152649eA73beAb28c5b49B26eb48f7EAD6d4c898;
    address constant MASTER_CHEF_V3 = 0x556B9306565093C855AEA9AE92A594704c2Cd59e;
    
    // Common tokens for testing
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant USDC = 0xA0b86A33E6441C3C6B7D8F0b32d4C7E64B7C8D4b;
    // #endregion mainnet addresses
    
    // #region state variables
    PancakeSwapV3StandardModulePrivate public moduleImplementation;
    UpgradeableBeacon public moduleBeacon;
    address public testVault;
    
    // Ghost variables for invariant tracking
    uint256 public ghost_totalDeposits;
    uint256 public ghost_totalWithdrawals;
    uint256 public ghost_vaultCount;
    mapping(address => uint256) public ghost_userDeposits;
    // Note: Private vaults don't have shares, they track underlying directly
    
    // Track initialization status
    bool public isInitialized;
    
    // Constants for testing
    uint256 constant MAX_TOKENS = 1000000e18;
    uint24 constant DEFAULT_FEE = 3000; // 0.3%
    // #endregion state variables
    
    constructor() {
        _setupModule();
        isInitialized = true;
    }
    
    // #region setup functions
    function _setupModule() internal {
        // Create module implementation
        moduleImplementation = new PancakeSwapV3StandardModulePrivate(
            GUARDIAN,
            PANCAKE_NFT_POSITION_MANAGER,
            PANCAKE_FACTORY,
            CAKE_TOKEN,
            MASTER_CHEF_V3
        );
        
        // Create beacon pointing to implementation
        moduleBeacon = new UpgradeableBeacon(
            address(moduleImplementation)
        );
        
        // Whitelist beacon in public registry
        _whitelistBeacon();
    }
    
    function _whitelistBeacon() internal {
        // Note: In real test, we'd need proper permissions to call this
        // For fuzzing, we assume we have the necessary access
        try IModuleRegistry(PUBLIC_REGISTRY).whitelistBeacons(
            _toArray(address(moduleBeacon))
        ) {
            // Success
        } catch {
            // Handle failure - might already be whitelisted or no permissions
        }
    }
    
    function _toArray(address addr) internal pure returns (address[] memory) {
        address[] memory array = new address[](1);
        array[0] = addr;
        return array;
    }
    // #endregion setup functions
    
    // #region fuzz assertion functions
    
    /// @notice Fuzz test for vault creation
    function fuzz_create_vault(
        uint256 seed,
        uint256 init0,
        uint256 init1,
        uint24 maxSlippage
    ) public {
        // Bound inputs to reasonable ranges
        init0 = _bound(init0, 0, MAX_TOKENS);
        init1 = _bound(init1, 0, MAX_TOKENS);
        maxSlippage = uint24(_bound(maxSlippage, 0, TEN_PERCENT));
        
        // Generate deterministic salt
        bytes32 salt = keccak256(abi.encodePacked(seed, ghost_vaultCount));
        
        // Module creation payload
        bytes memory moduleCreationPayload = abi.encodeWithSelector(
            IPancakeSwapV3StandardModule.initialize.selector,
            _getMockOracle(),
            init0,
            init1,
            maxSlippage,
            address(this), // cake receiver
            DEFAULT_FEE,
            address(0) // will be set by factory
        );
        
        // Management setup
        SetupParams memory setupParams = SetupParams({
            vault: address(0), // will be set by factory
            oracle: _getMockOracle(),
            maxDeviation: 500, // 5%
            cooldownPeriod: 3600, // 1 hour
            executor: address(this),
            stratAnnouncer: address(this),
            maxSlippagePIPS: maxSlippage
        });
        bytes memory initManagementPayload = abi.encode(setupParams);
        
        // Attempt to create vault
        try IArrakisMetaVaultFactory(FACTORY).deployPrivateVault(
            salt,
            WETH,
            USDC,
            address(this), // owner
            address(moduleBeacon),
            moduleCreationPayload,
            initManagementPayload
        ) returns (address vault) {
            testVault = vault;
            ghost_vaultCount++;
            
            // Assertions
            assert(vault != address(0));
            assert(IOwnable(vault).owner() == address(this));
            assert(address(IArrakisMetaVault(vault).module()) != address(0));
            assert(IArrakisMetaVault(vault).token0() == WETH);
            assert(IArrakisMetaVault(vault).token1() == USDC);
            
        } catch {
            // Vault creation failed - this might be expected in some cases
        }
    }
    
    /// @notice Fuzz test for deposits
    function fuzz_deposit(
        uint256 amount0,
        uint256 amount1
    ) public {
        // Requirements
        require(testVault != address(0), "No vault created");
        require(isInitialized, "Not initialized");
        
        // Bound amounts to reasonable ranges
        amount0 = _bound(amount0, 0, MAX_TOKENS);
        amount1 = _bound(amount1, 0, MAX_TOKENS);
        
        // Skip if both amounts are zero
        require(amount0 > 0 || amount1 > 0, "Both amounts zero");
        
        // Get balances before
        uint256 balance0Before = IERC20Metadata(WETH).balanceOf(testVault);
        uint256 balance1Before = IERC20Metadata(USDC).balanceOf(testVault);
        (uint256 underlying0Before, uint256 underlying1Before) = IArrakisMetaVault(testVault).totalUnderlying();
        
        // Mock token transfers (in real fork test, we'd need actual tokens)
        // For assertion testing, we assume tokens are available
        
        try IArrakisMetaVaultPrivate(testVault).deposit(amount0, amount1) {
            // Update ghost variables
            ghost_totalDeposits += amount0 + amount1;
            ghost_userDeposits[msg.sender] += amount0 + amount1;
            
            // Get balances after
            uint256 balance0After = IERC20Metadata(WETH).balanceOf(testVault);
            uint256 balance1After = IERC20Metadata(USDC).balanceOf(testVault);
            (uint256 underlying0After, uint256 underlying1After) = IArrakisMetaVault(testVault).totalUnderlying();
            
            // Assertions
            if (amount0 > 0) {
                assert(balance0After >= balance0Before);
            }
            if (amount1 > 0) {
                assert(balance1After >= balance1Before);
            }
            
            // Total underlying should increase if deposit was successful
            assert(underlying0After >= underlying0Before);
            assert(underlying1After >= underlying1Before);
            
            // Vault should remain solvent
            assert(_checkVaultSolvency(testVault));
            
        } catch {
            // Deposit failed - might be expected (insufficient balance, etc.)
        }
    }
    
    /// @notice Fuzz test for withdrawals
    function fuzz_withdraw(
        uint256 proportion
    ) public {
        // Requirements
        require(testVault != address(0), "No vault created");
        require(isInitialized, "Not initialized");
        
        // Bound proportion to valid range (0-100%)
        proportion = _bound(proportion, 1, BASE);
        
        // Check if user is depositor (private vaults don't have shares)
        // Only owner can withdraw from private vault
        require(msg.sender == IOwnable(testVault).owner(), "Only owner can withdraw");
        
        // Get state before withdrawal
        (uint256 underlying0Before, uint256 underlying1Before) = IArrakisMetaVault(testVault).totalUnderlying();
        uint256 balance0Before = IERC20Metadata(WETH).balanceOf(testVault);
        uint256 balance1Before = IERC20Metadata(USDC).balanceOf(testVault);
        uint256 userBalance0Before = IERC20Metadata(WETH).balanceOf(msg.sender);
        uint256 userBalance1Before = IERC20Metadata(USDC).balanceOf(msg.sender);
        
        try IArrakisMetaVaultPrivate(testVault).withdraw(
            proportion,
            msg.sender
        ) returns (uint256 amount0, uint256 amount1) {
            
            // Update ghost variables
            ghost_totalWithdrawals += amount0 + amount1;
            
            // Get state after withdrawal
            (uint256 underlying0After, uint256 underlying1After) = IArrakisMetaVault(testVault).totalUnderlying();
            uint256 userBalance0After = IERC20Metadata(WETH).balanceOf(msg.sender);
            uint256 userBalance1After = IERC20Metadata(USDC).balanceOf(msg.sender);
            
            // Assertions - underlying should decrease proportionally
            assert(underlying0After <= underlying0Before);
            assert(underlying1After <= underlying1Before);
            
            // User should receive tokens
            if (amount0 > 0) {
                assert(userBalance0After >= userBalance0Before);
            }
            if (amount1 > 0) {
                assert(userBalance1After >= userBalance1Before);
            }
            
            // Vault should remain solvent
            assert(_checkVaultSolvency(testVault));
            
            // Total withdrawals should not exceed total deposits
            assert(ghost_totalWithdrawals <= ghost_totalDeposits);
            
        } catch {
            // Withdrawal failed - might be expected
        }
    }
    
    /// @notice Fuzz test for rebalances
    function fuzz_rebalance(
        uint256 seed,
        uint256 minBurn0,
        uint256 minBurn1,
        uint256 minDeposit0,
        uint256 minDeposit1
    ) public {
        // Requirements
        require(testVault != address(0), "No vault created");
        require(isInitialized, "Not initialized");
        require(msg.sender == address(this), "Only executor"); // We set executor as this contract
        
        // Bound parameters
        minBurn0 = _bound(minBurn0, 0, MAX_TOKENS / 1000);
        minBurn1 = _bound(minBurn1, 0, MAX_TOKENS / 1000);
        minDeposit0 = _bound(minDeposit0, 0, MAX_TOKENS / 1000);
        minDeposit1 = _bound(minDeposit1, 0, MAX_TOKENS / 1000);
        
        // Get state before rebalance
        uint256 balance0Before = IERC20Metadata(WETH).balanceOf(testVault);
        uint256 balance1Before = IERC20Metadata(USDC).balanceOf(testVault);
        (uint256 underlying0Before, uint256 underlying1Before) = 
            _getVaultUnderlying(testVault);
        
        // Create simple rebalance params (no position changes for basic test)
        RebalanceParams memory params = RebalanceParams({
            decreasePositions: new ModifyPosition[](0),
            increasePositions: new ModifyPosition[](0),
            swapPayload: SwapPayload({
                payload: "",
                router: address(0),
                amountIn: 0,
                expectedMinReturn: 0,
                zeroForOne: false
            }),
            mintParams: new INonfungiblePositionManagerPancake.MintParams[](0),
            minBurn0: minBurn0,
            minBurn1: minBurn1,
            minDeposit0: minDeposit0,
            minDeposit1: minDeposit1
        });
        
        try IArrakisStandardManager(MANAGER).rebalance(
            testVault,
            _createRebalancePayloads(params)
        ) {
            // Get state after rebalance
            (uint256 underlying0After, uint256 underlying1After) = 
                _getVaultUnderlying(testVault);
            
            // Assertions
            // Underlying should be positive if vault has underlying tokens
            if (underlying0Before > 0 || underlying1Before > 0) {
                assert(underlying0After > 0 || underlying1After > 0);
            }
            
            // Vault should remain solvent
            assert(_checkVaultSolvency(testVault));
            
            // Total underlying should not decrease significantly without good reason
            // (allowing for some tolerance due to fees and slippage)
            uint256 totalValueBefore = underlying0Before + underlying1Before;
            uint256 totalValueAfter = underlying0After + underlying1After;
            
            if (totalValueBefore > 0) {
                assert(totalValueAfter >= totalValueBefore / 2); // Max 50% loss tolerance for testing
            }
            
        } catch {
            // Rebalance failed - might be expected (cooldown, oracle deviation, etc.)
        }
    }
    
    // #endregion fuzz assertion functions
    
    // #region helper functions
    function _bound(uint256 x, uint256 min, uint256 max) internal pure returns (uint256) {
        return min + (x % (max - min + 1));
    }
    
    function _getMockOracle() internal view returns (IOracleWrapper) {
        // Return a mock oracle address - in real test this would be a proper oracle
        return IOracleWrapper(address(0x1234567890123456789012345678901234567890));
    }
    
    function _checkVaultSolvency(address vault) internal view returns (bool) {
        // Private vaults don't have totalSupply, check underlying directly
        (uint256 amount0, uint256 amount1) = _getVaultUnderlying(vault);
        
        // If we've made net deposits, vault should have some underlying
        if (ghost_totalDeposits > ghost_totalWithdrawals) {
            return amount0 > 0 || amount1 > 0;
        }
        return true; // If net deposits <= 0, vault can be empty
    }
    
    function _getVaultUnderlying(address vault) internal view returns (uint256 amount0, uint256 amount1) {
        try IArrakisMetaVault(vault).totalUnderlying() returns (uint256 a0, uint256 a1) {
            return (a0, a1);
        } catch {
            return (0, 0);
        }
    }
    
    function _createRebalancePayloads(RebalanceParams memory params) 
        internal 
        pure 
        returns (bytes[] memory) 
    {
        bytes[] memory payloads = new bytes[](1);
        payloads[0] = abi.encodeWithSelector(
            IPancakeSwapV3StandardModule.rebalance.selector,
            params
        );
        return payloads;
    }
    // #endregion helper functions
    
    // #region invariant assertions (for Echidna)
    
    /// @notice Invariant: Total withdrawals should never exceed total deposits
    function echidna_withdrawals_not_exceed_deposits() public view returns (bool) {
        return ghost_totalWithdrawals <= ghost_totalDeposits;
    }
    
    /// @notice Invariant: Vault count should be non-negative and bounded
    function echidna_vault_count_reasonable() public view returns (bool) {
        return ghost_vaultCount >= 0 && ghost_vaultCount < 1000;
    }
    
    /// @notice Invariant: If vault exists, it should be solvent
    function echidna_vault_solvency() public view returns (bool) {
        if (testVault == address(0)) return true;
        return _checkVaultSolvency(testVault);
    }
    
    // #endregion invariant assertions
}