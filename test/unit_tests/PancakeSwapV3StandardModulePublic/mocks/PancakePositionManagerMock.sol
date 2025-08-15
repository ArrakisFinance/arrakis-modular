// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {INonfungiblePositionManagerPancake} from
    "../../../../src/interfaces/INonfungiblePositionManagerPancake.sol";
import {INonfungiblePositionManager} from
    "../../../../src/interfaces/INonfungiblePositionManager.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC721Metadata} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract PancakePositionManagerMock is ERC721, INonfungiblePositionManagerPancake {
    uint256 private _nextTokenId = 1;
    
    struct Position {
        uint96 nonce;
        address operator;
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint128 liquidity;
        uint256 feeGrowthInside0LastX128;
        uint256 feeGrowthInside1LastX128;
        uint128 tokensOwed0;
        uint128 tokensOwed1;
    }

    struct IncreaseLiquidityParams {
        uint256 tokenId;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        uint256 deadline;
    }

    struct DecreaseLiquidityParams {
        uint256 tokenId;
        uint128 liquidity;
        uint256 amount0Min;
        uint256 amount1Min;
        uint256 deadline;
    }

    struct CollectParams {
        uint256 tokenId;
        address recipient;
        uint128 amount0Max;
        uint128 amount1Max;
    }
    
    mapping(uint256 => Position) private _positions;
    address public factory;
    address public WETH9;

    constructor() ERC721("MockPositionManager", "MPM") {
        factory = address(this);
        WETH9 = address(0);
    }

    function mint(MintParams calldata params)
        external
        payable
        override
        returns (
            uint256 tokenId,
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1
        )
    {
        tokenId = _nextTokenId++;
        liquidity = 1000e18; // Mock liquidity
        amount0 = params.amount0Desired;
        amount1 = params.amount1Desired;
        
        _positions[tokenId] = Position({
            nonce: 0,
            operator: address(0),
            token0: params.token0,
            token1: params.token1,
            fee: params.fee,
            tickLower: params.tickLower,
            tickUpper: params.tickUpper,
            liquidity: liquidity,
            feeGrowthInside0LastX128: 0,
            feeGrowthInside1LastX128: 0,
            tokensOwed0: 0,
            tokensOwed1: 0
        });
        
        _mint(msg.sender, tokenId);
    }

    function increaseLiquidity(IncreaseLiquidityParams calldata params)
        external
        payable
        returns (uint128 liquidity, uint256 amount0, uint256 amount1)
    {
        liquidity = 100e18; // Mock additional liquidity
        amount0 = params.amount0Desired;
        amount1 = params.amount1Desired;
        
        _positions[params.tokenId].liquidity += liquidity;
    }

    function decreaseLiquidity(DecreaseLiquidityParams calldata params)
        external
        payable
        returns (uint256 amount0, uint256 amount1)
    {
        amount0 = uint256(params.liquidity) * 1e6 / 1e18; // Mock calculation
        amount1 = uint256(params.liquidity) * 1e18 / 1e18;
        
        _positions[params.tokenId].liquidity -= params.liquidity;
        _positions[params.tokenId].tokensOwed0 += uint128(amount0);
        _positions[params.tokenId].tokensOwed1 += uint128(amount1);
    }

    function collect(CollectParams calldata params)
        external
        payable
        returns (uint256 amount0, uint256 amount1)
    {
        Position storage position = _positions[params.tokenId];
        amount0 = position.tokensOwed0;
        amount1 = position.tokensOwed1;
        
        // Reset fees
        position.tokensOwed0 = 0;
        position.tokensOwed1 = 0;
    }

    function burn(uint256 tokenId) external {
        require(_exists(tokenId), "Token does not exist");
        require(_positions[tokenId].liquidity == 0, "Not cleared");
        delete _positions[tokenId];
        _burn(tokenId);
    }

    function positions(uint256 tokenId)
        external
        view
        returns (
            uint96 nonce,
            address operator,
            address token0,
            address token1,
            uint24 fee,
            int24 tickLower,
            int24 tickUpper,
            uint128 liquidity,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            uint128 tokensOwed0,
            uint128 tokensOwed1
        )
    {
        Position memory position = _positions[tokenId];
        return (
            position.nonce,
            position.operator,
            position.token0,
            position.token1,
            position.fee,
            position.tickLower,
            position.tickUpper,
            position.liquidity,
            position.feeGrowthInside0LastX128,
            position.feeGrowthInside1LastX128,
            position.tokensOwed0,
            position.tokensOwed1
        );
    }

    function setApprovalForAll(address operator, bool approved) public override {
        super.setApprovalForAll(operator, approved);
    }

    function transferFrom(address from, address to, uint256 tokenId) public override {
        super.transferFrom(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) public override {
        super.safeTransferFrom(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) public override {
        super.safeTransferFrom(from, to, tokenId, data);
    }

    function ownerOf(uint256 tokenId) public view override returns (address) {
        return super.ownerOf(tokenId);
    }

    function balanceOf(address owner) public view override returns (uint256) {
        return super.balanceOf(owner);
    }

    function getApproved(uint256 tokenId) public view override returns (address) {
        return super.getApproved(tokenId);
    }

    function isApprovedForAll(address owner, address operator) public view override returns (bool) {
        return super.isApprovedForAll(owner, operator);
    }

    function approve(address to, uint256 tokenId) public override {
        super.approve(to, tokenId);
    }

    // Mock function to add fees to a position for testing
    function addFeesToPosition(uint256 tokenId, uint128 fees0, uint128 fees1) external {
        _positions[tokenId].tokensOwed0 += fees0;
        _positions[tokenId].tokensOwed1 += fees1;
    }

    // Mock function to set liquidity for testing
    function setPositionLiquidity(uint256 tokenId, uint128 liquidity) external {
        _positions[tokenId].liquidity = liquidity;
    }
}