// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

// #region foundry.

import {TestWrapper} from "../../utils/TestWrapper.sol";
import {console} from "forge-std/console.sol";

// #endregion foundry.

import {IRFQWrapper} from "../../../src/interfaces/IRFQWrapper.sol";
import {IOracleWrapper} from
    "../../../src/interfaces/IOracleWrapper.sol";
import {RFQWrapper} from "../../../src/utils/RFQWrapper.sol";
import {TEN_PERCENT} from "../../../src/constants/CArrakis.sol";
import {RFQHelper} from "../../../src/libraries/RFQHelper.sol";
import {RequestForQuote} from
    "../../../src/structs/SRequestForQuote.sol";

// #region openzeppelin.

import {SafeCast} from
    "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {Pausable} from "@openzeppelin/contracts/security/Pausable.sol";
import {IERC20Metadata} from
    "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

// #endregion openzeppelin.

// #region mocks.

import {GuardianMock} from "./mocks/GuardianMock.sol";
import {ModuleMock} from "./mocks/ModuleMock.sol";
import {OracleMock} from "./mocks/OracleMock.sol";

// #endregion mocks.

// #region solady.

import {Ownable} from "@solady/contracts/auth/Ownable.sol";

// #endregion solady.

contract RFQWrapperTest is TestWrapper {
    // #region constants.

    address public constant WETH =
        0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant USDC =
        0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    bytes32 constant EXPECTED_RFQ_EIP712HASH = keccak256(
        "RequestForQuote(uint256 amountIn,uint256 amountOut,address module,address authorizedSender,address authorizedRecipient,uint32 signatureTimestamp,uint32 expiry,uint8 nonce,uint8 expectedFlag,bool isZeroToOne)"
    );

    // #endregion constants.

    address public owner;
    address public pauser;
    uint256 public signerPK;
    address public signer;

    address public guardian;
    address public module;

    uint128 public maxToken0VolumeToQuote;
    uint128 public maxToken1VolumeToQuote;
    uint32 public maxDelay;
    uint8 public maxAllowedQuotes;
    uint24 public maxDeviation;

    IOracleWrapper public oracle;

    RFQWrapper public rfqWrapper;

    function setUp() external {
        owner = vm.addr(uint256(keccak256(abi.encode("Owner"))));
        pauser = vm.addr(uint256(keccak256(abi.encode("Pauser"))));

        signerPK = uint256(keccak256(abi.encode("Signer")));
        signer = vm.addr(signerPK);

        // #region guardian mock.

        guardian = address(new GuardianMock());
        GuardianMock(guardian).setPauser(pauser);

        // #endregion guardian mock.

        // #region module mock.

        module = address(new ModuleMock());
        ModuleMock(module).setTokens(USDC, WETH);

        // #endregion module mock.

        // #region oracle mock.

        oracle = IOracleWrapper(address(new OracleMock()));

        // #endregion oracle mock.

        maxToken0VolumeToQuote = 10e18;
        maxToken1VolumeToQuote = 40_000e6;
        maxDelay = 60;
        maxAllowedQuotes = 1;
        maxDeviation = TEN_PERCENT;

        rfqWrapper =
            new RFQWrapper(guardian, owner, module, address(oracle));

        vm.prank(owner);
        rfqWrapper.initialize(
            signer,
            maxToken0VolumeToQuote,
            maxToken1VolumeToQuote,
            maxDelay,
            maxAllowedQuotes,
            maxDeviation
        );
    }

    // #region tests RFQHelper library.

    function test_rfq_eip_712_hash_lib() public {
        assertEq(RFQHelper.RFQ_EIP712HASH, EXPECTED_RFQ_EIP712HASH);
    }

    // #region test rfq state.

    function test_get_bitmap_lib() public {
        uint56 bitmap = type(uint56).max - 1;

        uint256 rfqState = (uint256(bitmap << 100)) ^ uint256(bitmap);

        assertEq(RFQHelper.getBitMap(rfqState), bitmap);
    }

    function test_get_last_processed_quote_timestamp_lib() public {
        uint56 bitmap = type(uint56).max - 1;
        uint32 lastProcessedQuoteTimestamp = 100;

        uint256 rfqState = uint256(
            (bytes32(uint256(lastProcessedQuoteTimestamp)) << 56)
                ^ bytes32(uint256(bitmap))
        );

        assertEq(
            RFQHelper.getLastProcessedQuoteTimestamp(rfqState),
            lastProcessedQuoteTimestamp
        );
    }

    function test_get_last_processed_block_quote_count_lib() public {
        uint56 bitmap = type(uint56).max - 1;
        uint32 lastProcessedQuoteTimestamp = 100;
        uint8 lastProcessedBlockQuoteCount = 5;

        uint256 rfqState = uint256(
            (bytes32(uint256(lastProcessedBlockQuoteCount)) << 88)
                ^ (bytes32(uint256(lastProcessedQuoteTimestamp)) << 56)
                ^ bytes32(uint256(bitmap))
        );

        assertEq(
            RFQHelper.getLastProcessedBlockQuoteCount(rfqState),
            lastProcessedBlockQuoteCount
        );
    }

    // #endregion test rfq state.

    // #region state change rfq state.

    function test_set_rfq_state_lib() public {
        uint56 bitmap = type(uint56).max - 1;
        uint32 lastProcessedQuoteTimestamp = 100;
        uint8 lastProcessedBlockQuoteCount = 5;

        uint256 rfqState = RFQHelper.setRfqState(
            bitmap,
            lastProcessedQuoteTimestamp,
            lastProcessedBlockQuoteCount
        );

        assertEq(RFQHelper.getBitMap(rfqState), bitmap);
        assertEq(
            RFQHelper.getLastProcessedQuoteTimestamp(rfqState),
            lastProcessedQuoteTimestamp
        );
        assertEq(
            RFQHelper.getLastProcessedBlockQuoteCount(rfqState),
            lastProcessedBlockQuoteCount
        );
    }

    // #endregion state change rfq state.

    // #region test max volume state.

    function test_get_max_token0_volume_to_quote_lib() public {
        uint128 maxToken0VolumeToQuote = 10e18;
        uint128 maxToken1VolumeToQuote = 40_000e6;

        uint256 maxVolumeState = uint256(
            (bytes32(uint256(maxToken1VolumeToQuote)) << 128)
                ^ bytes32(uint256(maxToken0VolumeToQuote))
        );

        assertEq(
            RFQHelper.getMaxToken0VolumeToQuote(maxVolumeState),
            maxToken0VolumeToQuote
        );
    }

    function test_get_max_token1_volume_to_quote_lib() public {
        uint128 maxToken0VolumeToQuote = 10e18;
        uint128 maxToken1VolumeToQuote = 40_000e6;

        uint256 maxVolumeState = uint256(
            (bytes32(uint256(maxToken1VolumeToQuote)) << 128)
                ^ bytes32(uint256(maxToken0VolumeToQuote))
        );

        assertEq(
            RFQHelper.getMaxToken1VolumeToQuote(maxVolumeState),
            maxToken1VolumeToQuote
        );
    }

    function test_set_max_token0_volume_to_quote_lib() public {
        uint128 maxToken0VolumeToQuote = 10e18;
        uint128 maxToken1VolumeToQuote = 40_000e6;

        uint256 maxVolumeState = uint256(
            (bytes32(uint256(maxToken1VolumeToQuote)) << 128)
                ^ bytes32(uint256(maxToken0VolumeToQuote))
        );

        maxToken0VolumeToQuote = 10e18 + 10;

        maxVolumeState = RFQHelper.setMaxToken0VolumeToQuote(
            maxVolumeState, maxToken0VolumeToQuote
        );

        assertEq(
            RFQHelper.getMaxToken0VolumeToQuote(maxVolumeState),
            maxToken0VolumeToQuote
        );
        assertEq(
            RFQHelper.getMaxToken1VolumeToQuote(maxVolumeState),
            maxToken1VolumeToQuote
        );
    }

    function test_set_max_token1_volume_to_quote_lib() public {
        uint128 maxToken0VolumeToQuote = 10e18;
        uint128 maxToken1VolumeToQuote = 40_000e6;

        uint256 maxVolumeState = uint256(
            (bytes32(uint256(maxToken1VolumeToQuote)) << 128)
                ^ bytes32(uint256(maxToken0VolumeToQuote))
        );

        maxToken1VolumeToQuote = 40_000e6 + 10;

        maxVolumeState = RFQHelper.setMaxToken1VolumeToQuote(
            maxVolumeState, maxToken1VolumeToQuote
        );

        assertEq(
            RFQHelper.getMaxToken0VolumeToQuote(maxVolumeState),
            maxToken0VolumeToQuote
        );
        assertEq(
            RFQHelper.getMaxToken1VolumeToQuote(maxVolumeState),
            maxToken1VolumeToQuote
        );
    }

    // #endregion test max volume state.

    // #region test internal state.

    function test_get_signer_lib() public {
        address signer =
            vm.addr(uint256(keccak256(abi.encode("Signer"))));

        uint256 internalState =
            (uint256(uint160(signer))) | (uint256(101) << 160);

        assertEq(RFQHelper.getSigner(internalState), signer);
    }

    function test_set_signer_lib() public {
        address signer =
            vm.addr(uint256(keccak256(abi.encode("Signer"))));

        uint256 internalState =
            (uint256(uint160(signer))) | (uint256(101) << 160);

        signer = vm.addr(uint256(keccak256(abi.encode("New Signer"))));

        internalState = RFQHelper.setSigner(internalState, signer);

        assertEq(RFQHelper.getSigner(internalState), signer);
    }

    function test_get_max_delay_lib() public {
        address signer =
            vm.addr(uint256(keccak256(abi.encode("Signer"))));

        uint256 internalState =
            (uint256(uint160(signer))) | (uint256(uint32(101)) << 160);

        assertEq(RFQHelper.getMaxDelay(internalState), uint32(101));
    }

    function test_set_max_delay_lib() public {
        address signer =
            vm.addr(uint256(keccak256(abi.encode("Signer"))));

        uint32 maxDelay = 101;

        uint256 internalState =
            (uint256(uint160(signer))) | (uint256(maxDelay) << 160);

        maxDelay = 110;

        internalState = RFQHelper.setMaxDelay(internalState, maxDelay);

        assertEq(RFQHelper.getMaxDelay(internalState), maxDelay);
    }

    function test_get_max_deviation_lib() public {
        address signer =
            vm.addr(uint256(keccak256(abi.encode("Signer"))));

        uint32 maxDelay = 100;

        uint24 maxDeviation = TEN_PERCENT;

        uint256 internalState = (uint256(uint160(signer)))
            | (uint256(maxDelay) << 160) | (uint256(maxDeviation) << 192);

        assertEq(
            RFQHelper.getMaxDeviation(internalState), maxDeviation
        );
    }

    function test_set_max_deviation_lib() public {
        address signer =
            vm.addr(uint256(keccak256(abi.encode("Signer"))));

        uint32 maxDelay = 100;

        uint24 maxDeviation = TEN_PERCENT;

        uint256 internalState = (uint256(uint160(signer)))
            | (uint256(maxDelay) << 160) | (uint256(maxDeviation) << 192);

        assertEq(
            RFQHelper.getMaxDeviation(internalState), maxDeviation
        );

        maxDeviation = TEN_PERCENT + 1;

        internalState =
            RFQHelper.setMaxDeviation(internalState, maxDeviation);

        assertEq(
            RFQHelper.getMaxDeviation(internalState), maxDeviation
        );
    }

    function test_get_max_allowedQuotes_lib() public {
        address signer =
            vm.addr(uint256(keccak256(abi.encode("Signer"))));

        uint32 maxDelay = 100;

        uint24 maxDeviation = TEN_PERCENT;

        uint8 maxAllowedQuotes = 5;

        uint256 internalState = (uint256(uint160(signer)))
            | (uint256(maxDelay) << 160) | (uint256(maxDeviation) << 192)
            | (uint256(maxAllowedQuotes) << 216);

        assertEq(
            RFQHelper.getMaxAllowedQuotes(internalState),
            maxAllowedQuotes
        );
    }

    function test_set_max_allowedQuotes_lib() public {
        address signer =
            vm.addr(uint256(keccak256(abi.encode("Signer"))));

        uint32 maxDelay = 100;

        uint24 maxDeviation = TEN_PERCENT;

        uint8 maxAllowedQuotes = 5;

        uint256 internalState = (uint256(uint160(signer)))
            | (uint256(maxDelay) << 160) | (uint256(maxDeviation) << 192)
            | (uint256(maxAllowedQuotes) << 216);

        assertEq(
            RFQHelper.getMaxAllowedQuotes(internalState),
            maxAllowedQuotes
        );

        maxAllowedQuotes = 6;

        internalState = RFQHelper.setMaxAllowedQuotes(
            internalState, maxAllowedQuotes
        );

        assertEq(
            RFQHelper.getMaxAllowedQuotes(internalState),
            maxAllowedQuotes
        );
    }
    // #endregion test internal state.

    // #endregion tests RFQHelper library.

    // #region test constructor.

    function test_constructor_guardian_address_zero() public {
        vm.expectRevert(IRFQWrapper.AddressZero.selector);
        rfqWrapper =
            new RFQWrapper(address(0), owner, module, address(oracle));
    }

    function test_constructor_owner_address_zero() public {
        vm.expectRevert(IRFQWrapper.AddressZero.selector);
        rfqWrapper = new RFQWrapper(
            guardian, address(0), module, address(oracle)
        );
    }

    function test_constructor_module_address_zero() public {
        vm.expectRevert(IRFQWrapper.AddressZero.selector);
        rfqWrapper = new RFQWrapper(
            guardian, owner, address(0), address(oracle)
        );
    }

    function test_constructor_oracle_address_zero() public {
        vm.expectRevert(IRFQWrapper.AddressZero.selector);
        rfqWrapper =
            new RFQWrapper(guardian, owner, module, address(0));
    }

    // #endregion test constructor.

    // #region test initialize.

    function test_initialize_unauthorized() public {
        rfqWrapper =
            new RFQWrapper(guardian, owner, module, address(oracle));

        vm.expectRevert(Ownable.Unauthorized.selector);
        rfqWrapper.initialize(
            address(0),
            maxToken0VolumeToQuote,
            maxToken1VolumeToQuote,
            maxDelay,
            maxAllowedQuotes,
            maxDeviation
        );
    }

    function test_initialize_signer_address_zero() public {
        rfqWrapper =
            new RFQWrapper(guardian, owner, module, address(oracle));

        vm.prank(owner);
        vm.expectRevert(IRFQWrapper.AddressZero.selector);
        rfqWrapper.initialize(
            address(0),
            maxToken0VolumeToQuote,
            maxToken1VolumeToQuote,
            maxDelay,
            maxAllowedQuotes,
            maxDeviation
        );
    }

    function test_initialize_max_token0_volume_to_quote_zero()
        public
    {
        rfqWrapper =
            new RFQWrapper(guardian, owner, module, address(oracle));

        vm.prank(owner);
        vm.expectRevert(IRFQWrapper.ZeroValue.selector);
        rfqWrapper.initialize(
            signer,
            0,
            maxToken1VolumeToQuote,
            maxDelay,
            maxAllowedQuotes,
            maxDeviation
        );
    }

    function test_initialize_max_token1_volume_to_quote_zero()
        public
    {
        rfqWrapper =
            new RFQWrapper(guardian, owner, module, address(oracle));

        vm.prank(owner);
        vm.expectRevert(IRFQWrapper.ZeroValue.selector);
        rfqWrapper.initialize(
            signer,
            maxToken0VolumeToQuote,
            0,
            maxDelay,
            maxAllowedQuotes,
            maxDeviation
        );
    }

    function test_initialize_max_delay_zero() public {
        rfqWrapper =
            new RFQWrapper(guardian, owner, module, address(oracle));

        vm.prank(owner);
        vm.expectRevert(IRFQWrapper.ZeroValue.selector);
        rfqWrapper.initialize(
            signer,
            maxToken0VolumeToQuote,
            maxToken1VolumeToQuote,
            0,
            maxAllowedQuotes,
            maxDeviation
        );
    }

    function test_initialize_max_allowed_quotes_zero() public {
        rfqWrapper =
            new RFQWrapper(guardian, owner, module, address(oracle));

        vm.prank(owner);
        vm.expectRevert(IRFQWrapper.ZeroValue.selector);
        rfqWrapper.initialize(
            signer,
            maxToken0VolumeToQuote,
            maxToken1VolumeToQuote,
            maxDelay,
            0,
            maxDeviation
        );
    }

    function test_initialize_max_deviation_zero() public {
        rfqWrapper =
            new RFQWrapper(guardian, owner, module, address(oracle));

        vm.prank(owner);
        vm.expectRevert(IRFQWrapper.MaxDeviation.selector);
        rfqWrapper.initialize(
            signer,
            maxToken0VolumeToQuote,
            maxToken1VolumeToQuote,
            maxDelay,
            maxAllowedQuotes,
            0
        );
    }

    function test_initialize_1() public {
        rfqWrapper =
            new RFQWrapper(guardian, owner, module, address(oracle));

        vm.prank(owner);
        rfqWrapper.initialize(
            signer,
            maxToken0VolumeToQuote,
            maxToken1VolumeToQuote,
            maxDelay,
            maxAllowedQuotes,
            maxDeviation
        );

        assertEq(rfqWrapper.signer(), signer);
        assertEq(
            rfqWrapper.maxToken0VolumeToQuote(),
            maxToken0VolumeToQuote
        );
        assertEq(
            rfqWrapper.maxToken1VolumeToQuote(),
            maxToken1VolumeToQuote
        );

        assertEq(rfqWrapper.maxAllowedQuotes(), maxAllowedQuotes);
        assertEq(rfqWrapper.maxDeviation(), maxDeviation);
        assertEq(rfqWrapper.maxDelay(), maxDelay);
    }

    // #endregion test initialize.

    // #region test pause/unpause.

    function test_pause_unauthorized() public {
        vm.expectRevert(IRFQWrapper.OnlyGuardian.selector);
        rfqWrapper.pause();
    }

    function test_pause() public {
        vm.prank(pauser);
        rfqWrapper.pause();

        assert(rfqWrapper.paused());
    }

    function test_unpause_unauthorized() public {
        vm.expectRevert(IRFQWrapper.OnlyGuardian.selector);
        rfqWrapper.unpause();
    }

    function test_unpause() public {
        vm.prank(pauser);
        rfqWrapper.pause();

        assert(rfqWrapper.paused());

        vm.prank(pauser);
        rfqWrapper.unpause();

        assert(!rfqWrapper.paused());
    }

    // #endregion test pause/unpause.

    // #region test set signer.

    function test_set_signer_unauthorized() public {
        vm.expectRevert(Ownable.Unauthorized.selector);
        rfqWrapper.setSigner(signer);
    }

    function test_set_signer_when_not_pauser() public {
        // #region pause rfqWrapper.

        vm.prank(pauser);
        rfqWrapper.pause();

        // #endregion pause rfqWrapper.

        vm.prank(owner);
        vm.expectRevert("Pausable: paused");
        rfqWrapper.setSigner(signer);
    }

    function test_set_signer_address_zero() public {
        vm.prank(owner);
        vm.expectRevert(IRFQWrapper.AddressZero.selector);
        rfqWrapper.setSigner(address(0));
    }

    function test_set_signer_same_signer() public {
        vm.prank(owner);
        vm.expectRevert(IRFQWrapper.SameSigner.selector);
        rfqWrapper.setSigner(signer);
    }

    function test_set_signer() public {
        address newSigner =
            vm.addr(uint256(keccak256(abi.encode("New Signer"))));

        vm.prank(owner);
        rfqWrapper.setSigner(newSigner);

        assertEq(rfqWrapper.signer(), newSigner);
    }

    // #endregion test set signer.

    // #region test set max allowed quotes.

    function test_set_max_allowed_quotes_unauthorized() public {
        vm.expectRevert(Ownable.Unauthorized.selector);
        rfqWrapper.setMaxAllowedQuotes(maxAllowedQuotes);
    }

    function test_set_max_allowed_quotes_paused() public {
        // #region pause rfqWrapper.

        vm.prank(pauser);
        rfqWrapper.pause();

        // #endregion pause rfqWrapper.

        vm.prank(owner);
        vm.expectRevert("Pausable: paused");
        rfqWrapper.setMaxAllowedQuotes(maxAllowedQuotes);
    }

    function test_set_max_allowed_quotes_zero_value() public {
        vm.prank(owner);
        vm.expectRevert(IRFQWrapper.ZeroValue.selector);
        rfqWrapper.setMaxAllowedQuotes(0);
    }

    function test_set_max_allowed_quotes() public {
        uint8 newMaxAllowedQuotes = 10;

        vm.prank(owner);
        rfqWrapper.setMaxAllowedQuotes(newMaxAllowedQuotes);

        assertEq(rfqWrapper.maxAllowedQuotes(), newMaxAllowedQuotes);
    }

    // #endregion test set max allowed quotes.

    // #region test set token volume to quote.

    function test_set_token_volume_to_quote_unauthorized() public {
        vm.expectRevert(Ownable.Unauthorized.selector);
        rfqWrapper.setMaxTokenVolumeToQuote(
            maxToken0VolumeToQuote, maxToken1VolumeToQuote
        );
    }

    function test_set_token_volume_to_quote_paused() public {
        // #region pause rfqWrapper.

        vm.prank(pauser);
        rfqWrapper.pause();

        // #endregion pause rfqWrapper.

        vm.prank(owner);
        vm.expectRevert("Pausable: paused");
        rfqWrapper.setMaxTokenVolumeToQuote(
            maxToken0VolumeToQuote, maxToken1VolumeToQuote
        );
    }

    function test_set_token_volume_to_quote_zero_value() public {
        vm.prank(owner);
        vm.expectRevert(IRFQWrapper.ZeroValue.selector);
        rfqWrapper.setMaxTokenVolumeToQuote(0, maxToken1VolumeToQuote);
    }

    function test_set_token_volume_to_quote_zero_value_bis() public {
        vm.prank(owner);
        vm.expectRevert(IRFQWrapper.ZeroValue.selector);
        rfqWrapper.setMaxTokenVolumeToQuote(maxToken0VolumeToQuote, 0);
    }

    function test_set_token_volume_to_quote() public {
        uint128 newMaxToken0VolumeToQuote = 10e18 + 10;
        uint128 newMaxToken1VolumeToQuote = 40_000e6 + 10;

        vm.prank(owner);
        rfqWrapper.setMaxTokenVolumeToQuote(
            newMaxToken0VolumeToQuote, newMaxToken1VolumeToQuote
        );

        assertEq(
            rfqWrapper.maxToken0VolumeToQuote(),
            newMaxToken0VolumeToQuote
        );
        assertEq(
            rfqWrapper.maxToken1VolumeToQuote(),
            newMaxToken1VolumeToQuote
        );
    }

    // #endregion test set token volume to quote.

    // #region test set max delay.

    function test_set_max_delay_unauthorized() public {
        vm.expectRevert(Ownable.Unauthorized.selector);
        rfqWrapper.setMaxDelay(maxDelay);
    }

    function test_set_max_delay_paused() public {
        // #region pause rfqWrapper.

        vm.prank(pauser);
        rfqWrapper.pause();

        // #endregion pause rfqWrapper.

        vm.prank(owner);
        vm.expectRevert("Pausable: paused");
        rfqWrapper.setMaxDelay(maxDelay);
    }

    function test_set_max_delay_zero_value() public {
        vm.prank(owner);
        vm.expectRevert(IRFQWrapper.ZeroValue.selector);
        rfqWrapper.setMaxDelay(0);
    }

    function test_set_max_delay() public {
        uint32 newMaxDelay = 70;

        vm.prank(owner);
        rfqWrapper.setMaxDelay(newMaxDelay);

        assertEq(rfqWrapper.maxDelay(), newMaxDelay);
    }

    // #endregion test set max delay.

    // #region test set max deviation.

    function test_set_max_deviation_unauthorized() public {
        vm.expectRevert(Ownable.Unauthorized.selector);
        rfqWrapper.setMaxDeviation(maxDeviation);
    }

    function test_set_max_deviation_paused() public {
        // #region pause rfqWrapper.

        vm.prank(pauser);
        rfqWrapper.pause();

        // #endregion pause rfqWrapper.

        vm.prank(owner);
        vm.expectRevert("Pausable: paused");
        rfqWrapper.setMaxDeviation(maxDeviation);
    }

    function test_set_max_deviation_zero_value() public {
        vm.prank(owner);
        vm.expectRevert(IRFQWrapper.ZeroValue.selector);
        rfqWrapper.setMaxDeviation(0);
    }

    function test_set_max_deviation_max_deviation() public {
        vm.prank(owner);
        vm.expectRevert(IRFQWrapper.MaxDeviation.selector);
        rfqWrapper.setMaxDeviation(TEN_PERCENT + 1);
    }

    function test_set_max_deviation() public {
        uint24 newMaxDeviation = TEN_PERCENT - 1;

        vm.prank(owner);
        rfqWrapper.setMaxDeviation(newMaxDeviation);

        assertEq(rfqWrapper.maxDeviation(), newMaxDeviation);
    }

    // #endregion test set max deviation.

    // #region test guardian view function.

    function test_guardian() public {
        assertEq(rfqWrapper.guardian(), pauser);
    }

    // #endregion test guardian view function.

    // #region test rfq swap.

    function test_rfq_swap_paused() public {
        // #region pause rfqWrapper.

        vm.prank(pauser);
        rfqWrapper.pause();

        // #endregion pause rfqWrapper.

        uint256 amountIn = 10e18;
        uint256 amountOut = 40_000e6;
        uint32 expiry = 100;
        uint8 nonce = 1;
        bool isZeroToOne = true;

        RequestForQuote memory requestForQuote = RequestForQuote({
            amountIn: amountIn,
            amountOut: amountOut,
            fee: 0,
            rfqwrapper: address(rfqWrapper),
            authorizedSender: address(0),
            authorizedRecipient: address(0),
            signatureTimestamp: 0,
            expiry: expiry,
            nonce: nonce,
            expectedFlag: 1,
            zeroForOne: isZeroToOne
        });

        bytes memory signature =
            abi.encodePacked(uint32(100), uint8(1), uint8(1));

        vm.expectRevert("Pausable: paused");
        rfqWrapper.rfqSwap(requestForQuote, signature);
    }

    function test_rfq_swap_wrong_rfq_wrapper() public {
        address wrongRFQWrapper =
            vm.addr(uint256(keccak256(abi.encode("RFQWrapper"))));

        uint256 amountIn = 10e18;
        uint256 amountOut = 40_000e6;
        uint32 expiry = 100;
        uint8 nonce = 1;
        bool isZeroToOne = true;

        RequestForQuote memory requestForQuote = RequestForQuote({
            amountIn: amountIn,
            amountOut: amountOut,
            fee: 0,
            rfqwrapper: wrongRFQWrapper,
            authorizedSender: address(0),
            authorizedRecipient: address(0),
            signatureTimestamp: 0,
            expiry: expiry,
            nonce: nonce,
            expectedFlag: 1,
            zeroForOne: isZeroToOne
        });

        // #region create a signature.

        bytes memory signature =
            getEOASignedDeal(requestForQuote, signerPK);

        // #endregion create a signature.
        vm.expectRevert(IRFQWrapper.WrongRFQWrapper.selector);
        rfqWrapper.rfqSwap(requestForQuote, signature);
    }

    function test_rfq_swap_not_valid_signature() public {
        uint256 amountIn = 10e18;
        uint256 amountOut = 40_000e6;
        uint32 expiry = 100;
        uint8 nonce = 1;
        bool isZeroToOne = true;

        RequestForQuote memory requestForQuote = RequestForQuote({
            amountIn: amountIn,
            amountOut: amountOut,
            fee: 0,
            rfqwrapper: address(rfqWrapper),
            authorizedSender: address(0),
            authorizedRecipient: address(0),
            signatureTimestamp: 0,
            expiry: expiry,
            nonce: nonce,
            expectedFlag: 1,
            zeroForOne: isZeroToOne
        });

        // #region create a signature.

        bytes memory signature =
            getEOASignedDeal(requestForQuote, signerPK);

        requestForQuote.fee = 1;

        // #endregion create a signature.
        vm.expectRevert(IRFQWrapper.NotValidSignature.selector);
        rfqWrapper.rfqSwap(requestForQuote, signature);
    }

    function test_rfq_swap_not_authorized() public {
        uint256 amountIn = 10e18;
        uint256 amountOut = 40_000e6;
        uint32 expiry = 100;
        uint8 nonce = 1;
        bool isZeroToOne = true;

        RequestForQuote memory requestForQuote = RequestForQuote({
            amountIn: amountIn,
            amountOut: amountOut,
            fee: 0,
            rfqwrapper: address(rfqWrapper),
            authorizedSender: address(0),
            authorizedRecipient: address(0),
            signatureTimestamp: 0,
            expiry: expiry,
            nonce: nonce,
            expectedFlag: 1,
            zeroForOne: isZeroToOne
        });

        // #region create a signature.

        bytes memory signature =
            getEOASignedDeal(requestForQuote, signerPK);

        // #endregion create a signature.
        vm.expectRevert(IRFQWrapper.NotAuthorized.selector);
        rfqWrapper.rfqSwap(requestForQuote, signature);
    }

    function test_rfq_swap_recipient_address_zero() public {
        address authorizedSender = vm.addr(
            uint256(keccak256(abi.encode("Authorized Sender")))
        );

        uint256 amountIn = 10e18;
        uint256 amountOut = 40_000e6;
        uint32 expiry = 100;
        uint8 nonce = 1;
        bool isZeroToOne = true;

        RequestForQuote memory requestForQuote = RequestForQuote({
            amountIn: amountIn,
            amountOut: amountOut,
            fee: 0,
            rfqwrapper: address(rfqWrapper),
            authorizedSender: authorizedSender,
            authorizedRecipient: address(0),
            signatureTimestamp: 0,
            expiry: expiry,
            nonce: nonce,
            expectedFlag: 1,
            zeroForOne: isZeroToOne
        });

        // #region create a signature.

        bytes memory signature =
            getEOASignedDeal(requestForQuote, signerPK);

        // #endregion create a signature.
        vm.prank(authorizedSender);
        vm.expectRevert(IRFQWrapper.AddressZero.selector);
        rfqWrapper.rfqSwap(requestForQuote, signature);
    }

    function test_rfq_swap_max_volume_out_case_1() public {
        address authorizedSender = vm.addr(
            uint256(keccak256(abi.encode("Authorized Sender")))
        );

        address authorizedRecipient = vm.addr(
            uint256(keccak256(abi.encode("Authorized Recipient")))
        );

        uint256 amountIn = 10e18;
        uint256 amountOut = type(uint256).max;
        uint32 expiry = 100;
        uint8 nonce = 1;
        bool isZeroToOne = true;

        RequestForQuote memory requestForQuote = RequestForQuote({
            amountIn: amountIn,
            amountOut: amountOut,
            fee: 0,
            rfqwrapper: address(rfqWrapper),
            authorizedSender: authorizedSender,
            authorizedRecipient: authorizedRecipient,
            signatureTimestamp: 0,
            expiry: expiry,
            nonce: nonce,
            expectedFlag: 1,
            zeroForOne: isZeroToOne
        });

        // #region create a signature.

        bytes memory signature =
            getEOASignedDeal(requestForQuote, signerPK);

        // #endregion create a signature.
        vm.prank(authorizedSender);
        vm.expectRevert(IRFQWrapper.MaximumVolumeOut.selector);
        rfqWrapper.rfqSwap(requestForQuote, signature);
    }

    function test_rfq_swap_max_volume_out_case_2() public {
        address authorizedSender = vm.addr(
            uint256(keccak256(abi.encode("Authorized Sender")))
        );

        address authorizedRecipient = vm.addr(
            uint256(keccak256(abi.encode("Authorized Recipient")))
        );

        uint256 amountIn = 10e18;
        uint256 amountOut = type(uint256).max;
        uint32 expiry = 100;
        uint8 nonce = 1;
        bool isZeroToOne = false;

        RequestForQuote memory requestForQuote = RequestForQuote({
            amountIn: amountIn,
            amountOut: amountOut,
            fee: 0,
            rfqwrapper: address(rfqWrapper),
            authorizedSender: authorizedSender,
            authorizedRecipient: authorizedRecipient,
            signatureTimestamp: 0,
            expiry: expiry,
            nonce: nonce,
            expectedFlag: 1,
            zeroForOne: isZeroToOne
        });

        // #region create a signature.

        bytes memory signature =
            getEOASignedDeal(requestForQuote, signerPK);

        // #endregion create a signature.
        vm.prank(authorizedSender);
        vm.expectRevert(IRFQWrapper.MaximumVolumeOut.selector);
        rfqWrapper.rfqSwap(requestForQuote, signature);
    }

    function test_rfq_swap_invalid_signature_timestamp() public {
        address authorizedSender = vm.addr(
            uint256(keccak256(abi.encode("Authorized Sender")))
        );

        address authorizedRecipient = vm.addr(
            uint256(keccak256(abi.encode("Authorized Recipient")))
        );

        uint256 amountIn = 10e18;
        uint256 amountOut = 40_000e6;
        uint32 expiry = 100;
        uint8 nonce = 1;
        bool isZeroToOne = false;

        RequestForQuote memory requestForQuote = RequestForQuote({
            amountIn: amountIn,
            amountOut: amountOut,
            fee: 0,
            rfqwrapper: address(rfqWrapper),
            authorizedSender: authorizedSender,
            authorizedRecipient: authorizedRecipient,
            signatureTimestamp: uint32(block.timestamp + 100),
            expiry: expiry,
            nonce: nonce,
            expectedFlag: 1,
            zeroForOne: isZeroToOne
        });

        // #region create a signature.

        bytes memory signature =
            getEOASignedDeal(requestForQuote, signerPK);

        // #endregion create a signature.
        vm.prank(authorizedSender);
        vm.expectRevert(
            IRFQWrapper.InvalidSignatureTimestamp.selector
        );
        rfqWrapper.rfqSwap(requestForQuote, signature);
    }

    function test_rfq_swap_quote_expired() public {
        address authorizedSender = vm.addr(
            uint256(keccak256(abi.encode("Authorized Sender")))
        );

        address authorizedRecipient = vm.addr(
            uint256(keccak256(abi.encode("Authorized Recipient")))
        );

        uint256 amountIn = 10e18;
        uint256 amountOut = 40_000e6;
        uint32 expiry = 100;
        uint8 nonce = 1;
        bool isZeroToOne = false;

        RequestForQuote memory requestForQuote = RequestForQuote({
            amountIn: amountIn,
            amountOut: amountOut,
            fee: 0,
            rfqwrapper: address(rfqWrapper),
            authorizedSender: authorizedSender,
            authorizedRecipient: authorizedRecipient,
            signatureTimestamp: 0,
            expiry: expiry,
            nonce: nonce,
            expectedFlag: 1,
            zeroForOne: isZeroToOne
        });

        // #region create a signature.

        bytes memory signature =
            getEOASignedDeal(requestForQuote, signerPK);

        // #endregion create a signature.
        vm.prank(authorizedSender);
        vm.expectRevert(IRFQWrapper.QuoteExpired.selector);
        rfqWrapper.rfqSwap(requestForQuote, signature);
    }

    function test_rfq_swap_invalid_expiry() public {
        address authorizedSender = vm.addr(
            uint256(keccak256(abi.encode("Authorized Sender")))
        );

        address authorizedRecipient = vm.addr(
            uint256(keccak256(abi.encode("Authorized Recipient")))
        );

        uint256 amountIn = 10e18;
        uint256 amountOut = 40_000e6;
        uint32 expiry = 100;
        uint8 nonce = 1;
        bool isZeroToOne = false;

        RequestForQuote memory requestForQuote = RequestForQuote({
            amountIn: amountIn,
            amountOut: amountOut,
            fee: 0,
            rfqwrapper: address(rfqWrapper),
            authorizedSender: authorizedSender,
            authorizedRecipient: authorizedRecipient,
            signatureTimestamp: uint32(block.timestamp - 50),
            expiry: expiry,
            nonce: nonce,
            expectedFlag: 1,
            zeroForOne: isZeroToOne
        });

        // #region create a signature.

        bytes memory signature =
            getEOASignedDeal(requestForQuote, signerPK);

        // #endregion create a signature.
        vm.prank(authorizedSender);
        vm.expectRevert(IRFQWrapper.InvalidExpiry.selector);
        rfqWrapper.rfqSwap(requestForQuote, signature);
    }

    function test_rfq_swap_invalid_nonce() public {
        address authorizedSender = vm.addr(
            uint256(keccak256(abi.encode("Authorized Sender")))
        );

        address authorizedRecipient = vm.addr(
            uint256(keccak256(abi.encode("Authorized Recipient")))
        );

        uint256 amountIn = 10e18;
        uint256 amountOut = 40_000e6;
        uint8 nonce = 1;
        bool isZeroToOne = false;

        RequestForQuote memory requestForQuote = RequestForQuote({
            amountIn: amountIn,
            amountOut: amountOut,
            fee: 0,
            rfqwrapper: address(rfqWrapper),
            authorizedSender: authorizedSender,
            authorizedRecipient: authorizedRecipient,
            signatureTimestamp: uint32(block.timestamp - 50),
            expiry: maxDelay,
            nonce: nonce,
            expectedFlag: 1,
            zeroForOne: isZeroToOne
        });

        // #region increase module balance.

        deal(USDC, module, amountOut);

        // #endregion increase module balance.

        // #region do approval module -> rfqWrapper.

        vm.prank(module);
        IERC20Metadata(USDC).approve(address(rfqWrapper), amountOut);

        // #endregion do approval module -> rfqWrapper.

        // #region create a signature.

        bytes memory signature =
            getEOASignedDeal(requestForQuote, signerPK);

        // #endregion create a signature.
        vm.prank(authorizedSender);
        vm.expectRevert(IRFQWrapper.InvalidNonce.selector);
        rfqWrapper.rfqSwap(requestForQuote, signature);
    }

    function test_rfq_swap_invalid_nonce_gt_55() public {
        address authorizedSender = vm.addr(
            uint256(keccak256(abi.encode("Authorized Sender")))
        );

        address authorizedRecipient = vm.addr(
            uint256(keccak256(abi.encode("Authorized Recipient")))
        );

        uint256 amountIn = 10e18;
        uint256 amountOut = 40_000e6;
        uint8 nonce = 56;
        bool isZeroToOne = false;

        RequestForQuote memory requestForQuote = RequestForQuote({
            amountIn: amountIn,
            amountOut: amountOut,
            fee: 0,
            rfqwrapper: address(rfqWrapper),
            authorizedSender: authorizedSender,
            authorizedRecipient: authorizedRecipient,
            signatureTimestamp: uint32(block.timestamp - 50),
            expiry: maxDelay,
            nonce: nonce,
            expectedFlag: 1,
            zeroForOne: isZeroToOne
        });

        // #region increase module balance.

        deal(USDC, module, amountOut);

        // #endregion increase module balance.

        // #region do approval module -> rfqWrapper.

        vm.prank(module);
        IERC20Metadata(USDC).approve(address(rfqWrapper), amountOut);

        // #endregion do approval module -> rfqWrapper.

        // #region create a signature.

        bytes memory signature =
            getEOASignedDeal(requestForQuote, signerPK);

        // #endregion create a signature.
        vm.prank(authorizedSender);
        vm.expectRevert(IRFQWrapper.InvalidNonce.selector);
        rfqWrapper.rfqSwap(requestForQuote, signature);
    }

    function test_rfq_swap_invalid_flag() public {
        address authorizedSender = vm.addr(
            uint256(keccak256(abi.encode("Authorized Sender")))
        );

        address authorizedRecipient = vm.addr(
            uint256(keccak256(abi.encode("Authorized Recipient")))
        );

        uint256 amountIn = 10e18;
        uint256 amountOut = 40_000e6;
        uint8 nonce = 50;
        bool isZeroToOne = false;

        RequestForQuote memory requestForQuote = RequestForQuote({
            amountIn: amountIn,
            amountOut: amountOut,
            fee: 0,
            rfqwrapper: address(rfqWrapper),
            authorizedSender: authorizedSender,
            authorizedRecipient: authorizedRecipient,
            signatureTimestamp: uint32(block.timestamp - 50),
            expiry: maxDelay,
            nonce: nonce,
            expectedFlag: 2,
            zeroForOne: isZeroToOne
        });

        // #region increase module balance.

        deal(USDC, module, amountOut);

        // #endregion increase module balance.

        // #region do approval module -> rfqWrapper.

        vm.prank(module);
        IERC20Metadata(USDC).approve(address(rfqWrapper), amountOut);

        // #endregion do approval module -> rfqWrapper.

        // #region create a signature.

        bytes memory signature =
            getEOASignedDeal(requestForQuote, signerPK);

        // #endregion create a signature.
        vm.prank(authorizedSender);
        vm.expectRevert(IRFQWrapper.InvalidFlag.selector);
        rfqWrapper.rfqSwap(requestForQuote, signature);
    }

    function test_rfq_swap_quote_price_deviation_case_1() public {
        address authorizedSender = vm.addr(
            uint256(keccak256(abi.encode("Authorized Sender")))
        );

        address authorizedRecipient = vm.addr(
            uint256(keccak256(abi.encode("Authorized Recipient")))
        );

        uint256 amountIn = 10e18;
        uint256 amountOut = 40_000e6;
        uint8 nonce = 1;
        bool isZeroToOne = false;

        RequestForQuote memory requestForQuote = RequestForQuote({
            amountIn: amountIn,
            amountOut: amountOut,
            fee: 0,
            rfqwrapper: address(rfqWrapper),
            authorizedSender: authorizedSender,
            authorizedRecipient: authorizedRecipient,
            signatureTimestamp: uint32(block.timestamp - 50),
            expiry: maxDelay,
            nonce: nonce,
            expectedFlag: 0,
            zeroForOne: isZeroToOne
        });

        // #region increase module balance.

        deal(USDC, module, amountOut);

        // #endregion increase module balance.

        // #region do approval module -> rfqWrapper.

        vm.prank(module);
        IERC20Metadata(USDC).approve(address(rfqWrapper), amountOut);

        // #endregion do approval module -> rfqWrapper.

        // #region create a signature.

        bytes memory signature =
            getEOASignedDeal(requestForQuote, signerPK);

        // #endregion create a signature.
        vm.prank(authorizedSender);
        vm.expectRevert(IRFQWrapper.QuotePriceDeviation.selector);
        rfqWrapper.rfqSwap(requestForQuote, signature);
    }

    function test_rfq_swap_quote_price_deviation_case_2() public {
        address authorizedSender = vm.addr(
            uint256(keccak256(abi.encode("Authorized Sender")))
        );

        address authorizedRecipient = vm.addr(
            uint256(keccak256(abi.encode("Authorized Recipient")))
        );

        uint256 amountIn = 40_000e6;
        uint256 amountOut = 10e18;
        uint8 nonce = 1;
        bool isZeroToOne = true;

        RequestForQuote memory requestForQuote = RequestForQuote({
            amountIn: amountIn,
            amountOut: amountOut,
            fee: 0,
            rfqwrapper: address(rfqWrapper),
            authorizedSender: authorizedSender,
            authorizedRecipient: authorizedRecipient,
            signatureTimestamp: uint32(block.timestamp - 50),
            expiry: maxDelay,
            nonce: nonce,
            expectedFlag: 0,
            zeroForOne: isZeroToOne
        });

        // #region increase module balance.

        deal(USDC, module, amountOut);

        // #endregion increase module balance.

        // #region do approval module -> rfqWrapper.

        vm.prank(module);
        IERC20Metadata(USDC).approve(address(rfqWrapper), amountOut);

        // #endregion do approval module -> rfqWrapper.

        // #region create a signature.

        bytes memory signature =
            getEOASignedDeal(requestForQuote, signerPK);

        // #endregion create a signature.
        vm.prank(authorizedSender);
        vm.expectRevert(IRFQWrapper.QuotePriceDeviation.selector);
        rfqWrapper.rfqSwap(requestForQuote, signature);
    }

    function test_rfq_swap_case_1() public {
        address authorizedSender = vm.addr(
            uint256(keccak256(abi.encode("Authorized Sender")))
        );

        address authorizedRecipient = vm.addr(
            uint256(keccak256(abi.encode("Authorized Recipient")))
        );

        uint256 amountIn = 10e18;
        uint256 amountOut = 20_000e6;
        uint8 nonce = 1;
        bool isZeroToOne = false;

        RequestForQuote memory requestForQuote = RequestForQuote({
            amountIn: amountIn,
            amountOut: amountOut,
            fee: 0,
            rfqwrapper: address(rfqWrapper),
            authorizedSender: authorizedSender,
            authorizedRecipient: authorizedRecipient,
            signatureTimestamp: uint32(block.timestamp - 50),
            expiry: maxDelay,
            nonce: nonce,
            expectedFlag: 0,
            zeroForOne: isZeroToOne
        });

        // #region increase module balance.

        deal(USDC, module, amountOut);
        deal(WETH, authorizedSender, amountIn);

        // #endregion increase module balance.

        // #region do approval module -> rfqWrapper.

        vm.prank(authorizedSender);
        IERC20Metadata(WETH).approve(address(rfqWrapper), amountIn);

        vm.prank(module);
        IERC20Metadata(USDC).approve(address(rfqWrapper), amountOut);

        // #endregion do approval module -> rfqWrapper.

        // #region create a signature.

        bytes memory signature =
            getEOASignedDeal(requestForQuote, signerPK);

        // #endregion create a signature.
        vm.prank(authorizedSender);
        rfqWrapper.rfqSwap(requestForQuote, signature);
    }

    function test_rfq_swap_case_2() public {
        address authorizedSender = vm.addr(
            uint256(keccak256(abi.encode("Authorized Sender")))
        );

        address authorizedRecipient = vm.addr(
            uint256(keccak256(abi.encode("Authorized Recipient")))
        );

        uint256 amountIn = 20_000e6;
        uint256 amountOut = 10e18;
        uint8 nonce = 1;
        bool isZeroToOne = true;

        RequestForQuote memory requestForQuote = RequestForQuote({
            amountIn: amountIn,
            amountOut: amountOut,
            fee: 0,
            rfqwrapper: address(rfqWrapper),
            authorizedSender: authorizedSender,
            authorizedRecipient: authorizedRecipient,
            signatureTimestamp: uint32(block.timestamp - 50),
            expiry: maxDelay,
            nonce: nonce,
            expectedFlag: 0,
            zeroForOne: isZeroToOne
        });

        // #region increase module balance.

        deal(USDC, authorizedSender, amountIn);
        deal(WETH, module, amountOut);

        // #endregion increase module balance.

        // #region do approval module -> rfqWrapper.

        vm.prank(authorizedSender);
        IERC20Metadata(USDC).approve(address(rfqWrapper), amountIn);

        vm.prank(module);
        IERC20Metadata(WETH).approve(address(rfqWrapper), amountOut);

        // #endregion do approval module -> rfqWrapper.

        // #region create a signature.

        bytes memory signature =
            getEOASignedDeal(requestForQuote, signerPK);

        // #endregion create a signature.
        vm.prank(authorizedSender);
        rfqWrapper.rfqSwap(requestForQuote, signature);
    }

    function test_rfq_swap_max_quotes_exceeded() public {
        address authorizedSender = vm.addr(
            uint256(keccak256(abi.encode("Authorized Sender")))
        );

        address authorizedRecipient = vm.addr(
            uint256(keccak256(abi.encode("Authorized Recipient")))
        );

        uint256 amountIn = 20_000e6;
        uint256 amountOut = 10e18;
        uint8 nonce = 1;
        bool isZeroToOne = true;

        RequestForQuote memory requestForQuote = RequestForQuote({
            amountIn: amountIn,
            amountOut: amountOut,
            fee: 0,
            rfqwrapper: address(rfqWrapper),
            authorizedSender: authorizedSender,
            authorizedRecipient: authorizedRecipient,
            signatureTimestamp: uint32(block.timestamp - 50),
            expiry: maxDelay,
            nonce: nonce,
            expectedFlag: 0,
            zeroForOne: isZeroToOne
        });

        // #region increase module balance.

        deal(USDC, authorizedSender, amountIn);
        deal(WETH, module, amountOut);

        // #endregion increase module balance.

        // #region do approval module -> rfqWrapper.

        vm.prank(authorizedSender);
        IERC20Metadata(USDC).approve(address(rfqWrapper), amountIn);

        vm.prank(module);
        IERC20Metadata(WETH).approve(address(rfqWrapper), amountOut);

        // #endregion do approval module -> rfqWrapper.

        // #region create a signature.

        bytes memory signature =
            getEOASignedDeal(requestForQuote, signerPK);

        // #endregion create a signature.
        vm.prank(authorizedSender);
        rfqWrapper.rfqSwap(requestForQuote, signature);

        vm.prank(authorizedSender);
        vm.expectRevert(IRFQWrapper.MaxQuotesExceeded.selector);
        rfqWrapper.rfqSwap(requestForQuote, signature);
    }

    // #endregion test rfq swap.

    // #region mock function.

    function getEOASignedDeal(
        RequestForQuote memory quote_,
        uint256 privateKey_
    ) public view returns (bytes memory) {
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                getDomainSeparatorV4(
                    block.chainid, address(rfqWrapper)
                ),
                keccak256(
                    abi.encode(RFQHelper.RFQ_EIP712HASH, quote_)
                )
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey_, digest);

        return abi.encodePacked(r, s, bytes1(v));
    }

    function getDomainSeparatorV4(
        uint256 chainId,
        address hook
    ) public view returns (bytes32 domainSeparator) {
        bytes32 typeHash = keccak256(
            "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
        );
        bytes32 hashedName = keccak256("RFQWrapper");
        bytes32 hashedVersion = keccak256("0.0.1");

        domainSeparator = keccak256(
            abi.encode(
                typeHash, hashedName, hashedVersion, chainId, hook
            )
        );
    }

    // #endregion mock function.
}
