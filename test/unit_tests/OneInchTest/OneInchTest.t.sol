// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

// #region foundry tests.
import {console} from "forge-std/console.sol";
import {Vm} from "forge-std/Vm.sol";
import {TestWrapper} from "../../utils/TestWrapper.sol";
import {stdJson} from "forge-std/StdJson.sol";
// #endregion foundry tests.

import {RouterSwapExecutor} from "../../../src/RouterSwapExecutor.sol";
import {ArrakisPublicVaultRouter} from
    "../../../src/ArrakisPublicVaultRouter.sol";
import {RouterSwapResolver} from "../../../src/RouterSwapResolver.sol";
import {AggregatorV3Interface} from
    "../../../src/interfaces/AggregatorV3Interface.sol";
import {IArrakisMetaVault} from
    "../../../src/interfaces/IArrakisMetaVault.sol";
import {
    SwapAndAddData,
    SwapData,
    AddLiquidityData
} from "../../../src/structs/SRouter.sol";
import {NATIVE_COIN} from "../../../src/constants/CArrakis.sol";

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {SafeCast} from
    "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract OneinchTest is TestWrapper {
    using Surl for *;
    using strings for *;
    using stdJson for string;

    using Strings for *;

    address public constant factory =
        0x248D28Ab0D26dDF10cd99B394eD387fD973DbE11;
    address public constant permit2 =
        0x000000000022D473030F116dDEE9F6B43aC78BA3;
    address public constant resolver =
        0xDa4D62149C778984524914DE9Ca062E866261459;

    address public router = 0xd3Db920D1403a5438A50d73f375b0DFf5a6Df9fC;
    address public swapper =
        0x902912E137DDC5F1c0c2A993880c4f68D18d2c75;

    /// @dev test is happening on arbitrum.

    string public constant networkId = "42161";

    address public constant tokenIn =
        0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address public constant tokenOut =
        0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
    uint256 public constant amount = 1_000_000_000_000_000_000;

    address public constant oneInchAggregator =
        0x111111125421cA6dc452d289314280a0f8842A65;

    address public constant vault =
        0x1fbdAfE1131A29E8AFe04CC6BCBEA449235574b3;

    address public constant chainlinkPriceFeed =
        0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612;

    function setUp() public {
        /// @dev specific fork.
        _reset(
            vm.envString("ONE_INCH_RPC_URL"),
            vm.envUint("ONE_INCH_BLOCK_NUMBER")
        );

        // router = address(
        //     new ArrakisPublicVaultRouter(
        //         NATIVE_COIN, permit2, address(this), factory, tokenIn
        //     )
        // );

        // swapper = address(new RouterSwapExecutor(router, NATIVE_COIN));

        // ArrakisPublicVaultRouter(payable(router)).updateSwapExecutor(
        //     swapper
        // );
    }

    function testQuote() public {
        int256 price18Decimals;

        (, price18Decimals,,,) = AggregatorV3Interface(
            chainlinkPriceFeed
        ).latestRoundData();

        price18Decimals = price18Decimals * 10 ** 10;

        uint256 amount0In = 1 ether;
        uint256 amount1In = 0;

        (bool zeroForOne, uint256 swapAmount) = RouterSwapResolver(
            0xDa4D62149C778984524914DE9Ca062E866261459
        ).calculateSwapAmount(
            IArrakisMetaVault(vault),
            amount0In,
            amount1In,
            SafeCast.toUint256(price18Decimals)
        );

        console.logBool(zeroForOne);
        console.logUint(swapAmount);

        uint256 amountOut = quote1Inch(tokenIn, tokenOut, swapAmount);

        // uint256 amountOut = 1_718_900_152;

        console.logAddress(address(this));

        console.logAddress(swapper);

        // bytes memory swapPayload = bytes(
        //     "0x07ed2379000000000000000000000000e37e799d5077682fa0a244d46e5649f71457bd0900000000000000000000000082af49447d8a07e3bd95bd0d56f35241523fbab1000000000000000000000000af88d065e77c8cc2239327c5edb3a432268e5831000000000000000000000000e37e799d5077682fa0a244d46e5649f71457bd09000000000000000000000000902912e137ddc5f1c0c2a993880c4f68d18d2c7500000000000000000000000000000000000000000000000006ec485370f3b3be00000000000000000000000000000000000000000000000000000000656d5ae900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000120000000000000000000000000000000000000000000000000000000000000008100000000000000000000000000000000000000000000000000000000006302a000000000000000000000000000000000000000000000000000000000656d5ae9ee63c1e5817fcdc35463e3770c2fb992716cd070b63540b94782af49447d8a07e3bd95bd0d56f35241523fbab1111111125421ca6dc452d289314280a0f8842a65000000000000000000000000000000000000000000000000000000000000004eb05a6e"
        // );

        //0x12aa3caf000000000000000000000000e37e799d5077682fa0a244d46e5649f71457bd0900000000000000000000000082af49447d8a07e3bd95bd0d56f35241523fbab1000000000000000000000000af88d065e77c8cc2239327c5edb3a432268e5831000000000000000000000000e37e799d5077682fa0a244d46e5649f71457bd0900000000000000000000000025e9b0576f92d431882f158bb8fb4ac47bdd7b9600000000000000000000000000000000000000000000000000002cfd11f1035f00000000000000000000000000000000000000000000000000000000000291470000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000014000000000000000000000000000000000000000000000000000000000000001600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000008100000000000000000000000000000000000000000000000000000000006302a00000000000000000000000000000000000000000000000000000000000028c56ee63c1e581b1026b8e7276e7ac75410f1fcbbe21796e8f752682af49447d8a07e3bd95bd0d56f35241523fbab11111111254eeb25477b68fb85ed929f73a960582000000000000000000000000000000000000000000000000000000000000004c20964a

        bytes memory swapPayload = swapTokenData(tokenIn, tokenOut, swapAmount);

        SwapData memory swapData = SwapData({
            swapPayload: swapPayload,
            amountInSwap: swapAmount,
            amountOutSwap: (amountOut * 99) / 100,
            swapRouter: oneInchAggregator,
            zeroForOne: zeroForOne
        });

        AddLiquidityData memory addData = AddLiquidityData({
            amount0Max: amount0In,
            amount1Max: amount1In,
            amount0Min: ((amount0In - swapAmount) * 98) / 100,
            amount1Min: (amountOut * 98) / 100,
            amountSharesMin: 0,
            vault: vault,
            receiver: address(this)
        });

        SwapAndAddData memory swapAndAddData =
            SwapAndAddData({swapData: swapData, addData: addData});

        deal(tokenIn, address(this), amount0In);

        IERC20(tokenIn).approve(router, amount0In);

        ArrakisPublicVaultRouter(payable(router)).swapAndAddLiquidity(
            swapAndAddData
        );

        console.log(
            "balance : %d ", IERC20(vault).balanceOf(address(this))
        );
    }

    // #region mock function 1inch.

    function quote1Inch(
        address tokenIn_,
        address tokenOut_,
        uint256 amount_
    ) public returns (uint256 amountOut) {
        string memory query = "https://api.1inch.dev/swap/v6.0/";

        string[] memory headers = new string[](3);
        headers[0] =
            "Authorization: Bearer wA6H0YimcyrlkbME9zd2fZFXezCNCIiT";
        headers[1] = "accept: application/json";
        headers[2] = "content-type: application/json";

        query = string.concat(query, networkId, "/quote?src=");
        query = string.concat(query, tokenIn_.toHexString(), "&dst=");
        query =
            string.concat(query, tokenOut_.toHexString(), "&amount=");
        query = string.concat(query, amount_.toString());

        console.logString(query);

        (uint256 status, bytes memory data) = query.get(headers);

        assertEq(status, 200);

        strings.slice memory responseText = string(data).toSlice();

        responseText.find("dstAmount".toSlice());

        console.logString("TOTO");

        console.logString(
            responseText.find("dstAmount".toSlice()).toString()
        );

        string(data).toSlice();

        string memory json = string(data);

        amountOut = json.readUint(".dstAmount");

        console.logUint(amountOut);
    }

    function swapTokenData(
        address tokenIn_,
        address tokenOut_,
        uint256 amount_
    ) public returns (bytes memory payload) {
        vm.sleep(500);
        string memory query = "https://api.1inch.dev/swap/v6.0/";

        string[] memory headers = new string[](3);
        headers[0] =
            "Authorization: Bearer wA6H0YimcyrlkbME9zd2fZFXezCNCIiT";
        headers[1] = "accept: application/json";
        headers[2] = "content-type: application/json";

        query = string.concat(query, networkId, "/swap?src=");
        query = string.concat(query, tokenIn_.toHexString(), "&dst=");
        query =
            string.concat(query, tokenOut_.toHexString(), "&amount=");
        query = string.concat(query, amount_.toString(), "&from=");
        query =
            string.concat(query, swapper.toHexString(), "&origin=");
        query = string.concat(
            query,
            address(this).toHexString(),
            "&slippage=1&disableEstimate=true"
        );

        (uint256 status, bytes memory data) = query.get(headers);

        assertEq(status, 200);

        string memory json = string(data);

        payload = json.readBytes(".tx.data");

        console.logString("Payload : ");
        console.logBytes(payload);
    }

    // #endregion mock function 1inch.
}

library Surl {
    Vm constant vm = Vm(
        address(
            bytes20(uint160(uint256(keccak256("hevm cheat code"))))
        )
    );

    function get(string memory self)
        internal
        returns (uint256 status, bytes memory data)
    {
        string[] memory empty = new string[](0);
        return get(self, empty);
    }

    function get(
        string memory self,
        string[] memory headers
    ) internal returns (uint256 status, bytes memory data) {
        return curl(self, headers, "", "GET");
    }

    function del(string memory self)
        internal
        returns (uint256 status, bytes memory data)
    {
        string[] memory empty = new string[](0);
        return curl(self, empty, "", "DELETE");
    }

    function del(
        string memory self,
        string memory body
    ) internal returns (uint256 status, bytes memory data) {
        string[] memory empty = new string[](0);
        return curl(self, empty, body, "DELETE");
    }

    function del(
        string memory self,
        string[] memory headers,
        string memory body
    ) internal returns (uint256 status, bytes memory data) {
        return curl(self, headers, body, "DELETE");
    }

    function patch(string memory self)
        internal
        returns (uint256 status, bytes memory data)
    {
        string[] memory empty = new string[](0);
        return curl(self, empty, "", "PATCH");
    }

    function patch(
        string memory self,
        string memory body
    ) internal returns (uint256 status, bytes memory data) {
        string[] memory empty = new string[](0);
        return curl(self, empty, body, "PATCH");
    }

    function patch(
        string memory self,
        string[] memory headers,
        string memory body
    ) internal returns (uint256 status, bytes memory data) {
        return curl(self, headers, body, "PATCH");
    }

    function post(string memory self)
        internal
        returns (uint256 status, bytes memory data)
    {
        string[] memory empty = new string[](0);
        return curl(self, empty, "", "POST");
    }

    function post(
        string memory self,
        string memory body
    ) internal returns (uint256 status, bytes memory data) {
        string[] memory empty = new string[](0);
        return curl(self, empty, body, "POST");
    }

    function post(
        string memory self,
        string[] memory headers,
        string memory body
    ) internal returns (uint256 status, bytes memory data) {
        return curl(self, headers, body, "POST");
    }

    function put(string memory self)
        internal
        returns (uint256 status, bytes memory data)
    {
        string[] memory empty = new string[](0);
        return curl(self, empty, "", "PUT");
    }

    function put(
        string memory self,
        string memory body
    ) internal returns (uint256 status, bytes memory data) {
        string[] memory empty = new string[](0);
        return curl(self, empty, body, "PUT");
    }

    function put(
        string memory self,
        string[] memory headers,
        string memory body
    ) internal returns (uint256 status, bytes memory data) {
        return curl(self, headers, body, "PUT");
    }

    function curl(
        string memory self,
        string[] memory headers,
        string memory body,
        string memory method
    ) internal returns (uint256 status, bytes memory data) {
        string memory scriptStart =
            'response=$(curl -s -w "\\n%{http_code}" ';
        string memory scriptEnd =
            '); status=$(tail -n1 <<< "$response"); data=$(sed "$ d" <<< "$response");data=$(echo "$data" | tr -d "\\n"); cast abi-encode "response(uint256,string)" "$status" "$data";';

        string memory curlParams = "";

        for (uint256 i = 0; i < headers.length; i++) {
            curlParams =
                string.concat(curlParams, '-H "', headers[i], '" ');
        }

        curlParams = string.concat(curlParams, " -X ", method, " ");

        if (bytes(body).length > 0) {
            curlParams =
                string.concat(curlParams, " -d \'", body, "\' ");
        }

        string memory quotedURL = string.concat('"', self, '"');

        string[] memory inputs = new string[](3);
        inputs[0] = "bash";
        inputs[1] = "-c";
        inputs[2] = string.concat(
            scriptStart, curlParams, quotedURL, scriptEnd, ""
        );
        bytes memory res = vm.ffi(inputs);

        (status, data) = abi.decode(res, (uint256, bytes));
    }
}

library strings {
    struct slice {
        uint256 _len;
        uint256 _ptr;
    }

    function memcpy(
        uint256 dest,
        uint256 src,
        uint256 length
    ) private pure {
        // Copy word-length chunks while possible
        for (; length >= 32; length -= 32) {
            assembly {
                mstore(dest, mload(src))
            }
            dest += 32;
            src += 32;
        }

        // Copy remaining bytes
        uint256 mask = type(uint256).max;
        if (length > 0) {
            mask = 256 ** (32 - length) - 1;
        }
        assembly {
            let srcpart := and(mload(src), not(mask))
            let destpart := and(mload(dest), mask)
            mstore(dest, or(destpart, srcpart))
        }
    }

    /*
     * @dev Returns a slice containing the entire string.
     * @param self The string to make a slice from.
     * @return A newly allocated slice containing the entire string.
     */
    function toSlice(string memory self)
        internal
        pure
        returns (slice memory)
    {
        uint256 ptr;
        assembly {
            ptr := add(self, 0x20)
        }
        return slice(bytes(self).length, ptr);
    }

    /*
     * @dev Returns the length of a null-terminated bytes32 string.
     * @param self The value to find the length of.
     * @return The length of the string, from 0 to 32.
     */
    function len(bytes32 self) internal pure returns (uint256) {
        uint256 ret;
        if (self == 0) {
            return 0;
        }
        if (uint256(self) & type(uint128).max == 0) {
            ret += 16;
            self = bytes32(
                uint256(self) / 0x100000000000000000000000000000000
            );
        }
        if (uint256(self) & type(uint64).max == 0) {
            ret += 8;
            self = bytes32(uint256(self) / 0x10000000000000000);
        }
        if (uint256(self) & type(uint32).max == 0) {
            ret += 4;
            self = bytes32(uint256(self) / 0x100000000);
        }
        if (uint256(self) & type(uint16).max == 0) {
            ret += 2;
            self = bytes32(uint256(self) / 0x10000);
        }
        if (uint256(self) & type(uint8).max == 0) {
            ret += 1;
        }
        return 32 - ret;
    }

    /*
     * @dev Returns a slice containing the entire bytes32, interpreted as a
     *      null-terminated utf-8 string.
     * @param self The bytes32 value to convert to a slice.
     * @return A new slice containing the value of the input argument up to the
     *         first null.
     */
    function toSliceB32(bytes32 self)
        internal
        pure
        returns (slice memory ret)
    {
        // Allocate space for `self` in memory, copy it there, and point ret at it
        assembly {
            let ptr := mload(0x40)
            mstore(0x40, add(ptr, 0x20))
            mstore(ptr, self)
            mstore(add(ret, 0x20), ptr)
        }
        ret._len = len(self);
    }

    /*
     * @dev Returns a new slice containing the same data as the current slice.
     * @param self The slice to copy.
     * @return A new slice containing the same data as `self`.
     */
    function copy(slice memory self)
        internal
        pure
        returns (slice memory)
    {
        return slice(self._len, self._ptr);
    }

    /*
     * @dev Copies a slice to a new string.
     * @param self The slice to copy.
     * @return A newly allocated string containing the slice's text.
     */
    function toString(slice memory self)
        internal
        pure
        returns (string memory)
    {
        string memory ret = new string(self._len);
        uint256 retptr;
        assembly {
            retptr := add(ret, 32)
        }

        memcpy(retptr, self._ptr, self._len);
        return ret;
    }

    /*
     * @dev Returns the length in runes of the slice. Note that this operation
     *      takes time proportional to the length of the slice; avoid using it
     *      in loops, and call `slice.empty()` if you only need to know whether
     *      the slice is empty or not.
     * @param self The slice to operate on.
     * @return The length of the slice in runes.
     */
    function len(slice memory self)
        internal
        pure
        returns (uint256 l)
    {
        // Starting at ptr-31 means the LSB will be the byte we care about
        uint256 ptr = self._ptr - 31;
        uint256 end = ptr + self._len;
        for (l = 0; ptr < end; l++) {
            uint8 b;
            assembly {
                b := and(mload(ptr), 0xFF)
            }
            if (b < 0x80) {
                ptr += 1;
            } else if (b < 0xE0) {
                ptr += 2;
            } else if (b < 0xF0) {
                ptr += 3;
            } else if (b < 0xF8) {
                ptr += 4;
            } else if (b < 0xFC) {
                ptr += 5;
            } else {
                ptr += 6;
            }
        }
    }

    /*
     * @dev Returns true if the slice is empty (has a length of 0).
     * @param self The slice to operate on.
     * @return True if the slice is empty, False otherwise.
     */
    function empty(slice memory self) internal pure returns (bool) {
        return self._len == 0;
    }

    /*
     * @dev Returns a positive number if `other` comes lexicographically after
     *      `self`, a negative number if it comes before, or zero if the
     *      contents of the two slices are equal. Comparison is done per-rune,
     *      on unicode codepoints.
     * @param self The first slice to compare.
     * @param other The second slice to compare.
     * @return The result of the comparison.
     */
    function compare(
        slice memory self,
        slice memory other
    ) internal pure returns (int256) {
        uint256 shortest = self._len;
        if (other._len < self._len) {
            shortest = other._len;
        }

        uint256 selfptr = self._ptr;
        uint256 otherptr = other._ptr;
        for (uint256 idx = 0; idx < shortest; idx += 32) {
            uint256 a;
            uint256 b;
            assembly {
                a := mload(selfptr)
                b := mload(otherptr)
            }
            if (a != b) {
                // Mask out irrelevant bytes and check again
                uint256 mask = type(uint256).max; // 0xffff...
                if (shortest < 32) {
                    mask = ~(2 ** (8 * (32 - shortest + idx)) - 1);
                }
                unchecked {
                    uint256 diff = (a & mask) - (b & mask);
                    if (diff != 0) {
                        return int256(diff);
                    }
                }
            }
            selfptr += 32;
            otherptr += 32;
        }
        return int256(self._len) - int256(other._len);
    }

    /*
     * @dev Returns true if the two slices contain the same text.
     * @param self The first slice to compare.
     * @param self The second slice to compare.
     * @return True if the slices are equal, false otherwise.
     */
    function equals(
        slice memory self,
        slice memory other
    ) internal pure returns (bool) {
        return compare(self, other) == 0;
    }

    /*
     * @dev Extracts the first rune in the slice into `rune`, advancing the
     *      slice to point to the next rune and returning `self`.
     * @param self The slice to operate on.
     * @param rune The slice that will contain the first rune.
     * @return `rune`.
     */
    function nextRune(
        slice memory self,
        slice memory rune
    ) internal pure returns (slice memory) {
        rune._ptr = self._ptr;

        if (self._len == 0) {
            rune._len = 0;
            return rune;
        }

        uint256 l;
        uint256 b;
        // Load the first byte of the rune into the LSBs of b
        assembly {
            b := and(mload(sub(mload(add(self, 32)), 31)), 0xFF)
        }
        if (b < 0x80) {
            l = 1;
        } else if (b < 0xE0) {
            l = 2;
        } else if (b < 0xF0) {
            l = 3;
        } else {
            l = 4;
        }

        // Check for truncated codepoints
        if (l > self._len) {
            rune._len = self._len;
            self._ptr += self._len;
            self._len = 0;
            return rune;
        }

        self._ptr += l;
        self._len -= l;
        rune._len = l;
        return rune;
    }

    /*
     * @dev Returns the first rune in the slice, advancing the slice to point
     *      to the next rune.
     * @param self The slice to operate on.
     * @return A slice containing only the first rune from `self`.
     */
    function nextRune(slice memory self)
        internal
        pure
        returns (slice memory ret)
    {
        nextRune(self, ret);
    }

    /*
     * @dev Returns the number of the first codepoint in the slice.
     * @param self The slice to operate on.
     * @return The number of the first codepoint in the slice.
     */
    function ord(slice memory self)
        internal
        pure
        returns (uint256 ret)
    {
        if (self._len == 0) {
            return 0;
        }

        uint256 word;
        uint256 length;
        uint256 divisor = 2 ** 248;

        // Load the rune into the MSBs of b
        assembly {
            word := mload(mload(add(self, 32)))
        }
        uint256 b = word / divisor;
        if (b < 0x80) {
            ret = b;
            length = 1;
        } else if (b < 0xE0) {
            ret = b & 0x1F;
            length = 2;
        } else if (b < 0xF0) {
            ret = b & 0x0F;
            length = 3;
        } else {
            ret = b & 0x07;
            length = 4;
        }

        // Check for truncated codepoints
        if (length > self._len) {
            return 0;
        }

        for (uint256 i = 1; i < length; i++) {
            divisor = divisor / 256;
            b = (word / divisor) & 0xFF;
            if (b & 0xC0 != 0x80) {
                // Invalid UTF-8 sequence
                return 0;
            }
            ret = (ret * 64) | (b & 0x3F);
        }

        return ret;
    }

    /*
     * @dev Returns the keccak-256 hash of the slice.
     * @param self The slice to hash.
     * @return The hash of the slice.
     */
    function keccak(slice memory self)
        internal
        pure
        returns (bytes32 ret)
    {
        assembly {
            ret := keccak256(mload(add(self, 32)), mload(self))
        }
    }

    /*
     * @dev Returns true if `self` starts with `needle`.
     * @param self The slice to operate on.
     * @param needle The slice to search for.
     * @return True if the slice starts with the provided text, false otherwise.
     */
    function startsWith(
        slice memory self,
        slice memory needle
    ) internal pure returns (bool) {
        if (self._len < needle._len) {
            return false;
        }

        if (self._ptr == needle._ptr) {
            return true;
        }

        bool equal;
        assembly {
            let length := mload(needle)
            let selfptr := mload(add(self, 0x20))
            let needleptr := mload(add(needle, 0x20))
            equal :=
                eq(
                    keccak256(selfptr, length),
                    keccak256(needleptr, length)
                )
        }
        return equal;
    }

    /*
     * @dev If `self` starts with `needle`, `needle` is removed from the
     *      beginning of `self`. Otherwise, `self` is unmodified.
     * @param self The slice to operate on.
     * @param needle The slice to search for.
     * @return `self`
     */
    function beyond(
        slice memory self,
        slice memory needle
    ) internal pure returns (slice memory) {
        if (self._len < needle._len) {
            return self;
        }

        bool equal = true;
        if (self._ptr != needle._ptr) {
            assembly {
                let length := mload(needle)
                let selfptr := mload(add(self, 0x20))
                let needleptr := mload(add(needle, 0x20))
                equal :=
                    eq(
                        keccak256(selfptr, length),
                        keccak256(needleptr, length)
                    )
            }
        }

        if (equal) {
            self._len -= needle._len;
            self._ptr += needle._len;
        }

        return self;
    }

    /*
     * @dev Returns true if the slice ends with `needle`.
     * @param self The slice to operate on.
     * @param needle The slice to search for.
     * @return True if the slice starts with the provided text, false otherwise.
     */
    function endsWith(
        slice memory self,
        slice memory needle
    ) internal pure returns (bool) {
        if (self._len < needle._len) {
            return false;
        }

        uint256 selfptr = self._ptr + self._len - needle._len;

        if (selfptr == needle._ptr) {
            return true;
        }

        bool equal;
        assembly {
            let length := mload(needle)
            let needleptr := mload(add(needle, 0x20))
            equal :=
                eq(
                    keccak256(selfptr, length),
                    keccak256(needleptr, length)
                )
        }

        return equal;
    }

    /*
     * @dev If `self` ends with `needle`, `needle` is removed from the
     *      end of `self`. Otherwise, `self` is unmodified.
     * @param self The slice to operate on.
     * @param needle The slice to search for.
     * @return `self`
     */
    function until(
        slice memory self,
        slice memory needle
    ) internal pure returns (slice memory) {
        if (self._len < needle._len) {
            return self;
        }

        uint256 selfptr = self._ptr + self._len - needle._len;
        bool equal = true;
        if (selfptr != needle._ptr) {
            assembly {
                let length := mload(needle)
                let needleptr := mload(add(needle, 0x20))
                equal :=
                    eq(
                        keccak256(selfptr, length),
                        keccak256(needleptr, length)
                    )
            }
        }

        if (equal) {
            self._len -= needle._len;
        }

        return self;
    }

    // Returns the memory address of the first byte of the first occurrence of
    // `needle` in `self`, or the first byte after `self` if not found.
    function findPtr(
        uint256 selflen,
        uint256 selfptr,
        uint256 needlelen,
        uint256 needleptr
    ) private pure returns (uint256) {
        uint256 ptr = selfptr;
        uint256 idx;

        if (needlelen <= selflen) {
            if (needlelen <= 32) {
                bytes32 mask;
                if (needlelen > 0) {
                    mask = bytes32(~(2 ** (8 * (32 - needlelen)) - 1));
                }

                bytes32 needledata;
                assembly {
                    needledata := and(mload(needleptr), mask)
                }

                uint256 end = selfptr + selflen - needlelen;
                bytes32 ptrdata;
                assembly {
                    ptrdata := and(mload(ptr), mask)
                }

                while (ptrdata != needledata) {
                    if (ptr >= end) {
                        return selfptr + selflen;
                    }
                    ptr++;
                    assembly {
                        ptrdata := and(mload(ptr), mask)
                    }
                }
                return ptr;
            } else {
                // For long needles, use hashing
                bytes32 hash;
                assembly {
                    hash := keccak256(needleptr, needlelen)
                }

                for (idx = 0; idx <= selflen - needlelen; idx++) {
                    bytes32 testHash;
                    assembly {
                        testHash := keccak256(ptr, needlelen)
                    }
                    if (hash == testHash) {
                        return ptr;
                    }
                    ptr += 1;
                }
            }
        }
        return selfptr + selflen;
    }

    // Returns the memory address of the first byte after the last occurrence of
    // `needle` in `self`, or the address of `self` if not found.
    function rfindPtr(
        uint256 selflen,
        uint256 selfptr,
        uint256 needlelen,
        uint256 needleptr
    ) private pure returns (uint256) {
        uint256 ptr;

        if (needlelen <= selflen) {
            if (needlelen <= 32) {
                bytes32 mask;
                if (needlelen > 0) {
                    mask = bytes32(~(2 ** (8 * (32 - needlelen)) - 1));
                }

                bytes32 needledata;
                assembly {
                    needledata := and(mload(needleptr), mask)
                }

                ptr = selfptr + selflen - needlelen;
                bytes32 ptrdata;
                assembly {
                    ptrdata := and(mload(ptr), mask)
                }

                while (ptrdata != needledata) {
                    if (ptr <= selfptr) {
                        return selfptr;
                    }
                    ptr--;
                    assembly {
                        ptrdata := and(mload(ptr), mask)
                    }
                }
                return ptr + needlelen;
            } else {
                // For long needles, use hashing
                bytes32 hash;
                assembly {
                    hash := keccak256(needleptr, needlelen)
                }
                ptr = selfptr + (selflen - needlelen);
                while (ptr >= selfptr) {
                    bytes32 testHash;
                    assembly {
                        testHash := keccak256(ptr, needlelen)
                    }
                    if (hash == testHash) {
                        return ptr + needlelen;
                    }
                    ptr -= 1;
                }
            }
        }
        return selfptr;
    }

    /*
     * @dev Modifies `self` to contain everything from the first occurrence of
     *      `needle` to the end of the slice. `self` is set to the empty slice
     *      if `needle` is not found.
     * @param self The slice to search and modify.
     * @param needle The text to search for.
     * @return `self`.
     */
    function find(
        slice memory self,
        slice memory needle
    ) internal pure returns (slice memory) {
        uint256 ptr =
            findPtr(self._len, self._ptr, needle._len, needle._ptr);
        self._len -= ptr - self._ptr;
        self._ptr = ptr;
        return self;
    }

    /*
     * @dev Modifies `self` to contain the part of the string from the start of
     *      `self` to the end of the first occurrence of `needle`. If `needle`
     *      is not found, `self` is set to the empty slice.
     * @param self The slice to search and modify.
     * @param needle The text to search for.
     * @return `self`.
     */
    function rfind(
        slice memory self,
        slice memory needle
    ) internal pure returns (slice memory) {
        uint256 ptr =
            rfindPtr(self._len, self._ptr, needle._len, needle._ptr);
        self._len = ptr - self._ptr;
        return self;
    }

    /*
     * @dev Splits the slice, setting `self` to everything after the first
     *      occurrence of `needle`, and `token` to everything before it. If
     *      `needle` does not occur in `self`, `self` is set to the empty slice,
     *      and `token` is set to the entirety of `self`.
     * @param self The slice to split.
     * @param needle The text to search for in `self`.
     * @param token An output parameter to which the first token is written.
     * @return `token`.
     */
    function split(
        slice memory self,
        slice memory needle,
        slice memory token
    ) internal pure returns (slice memory) {
        uint256 ptr =
            findPtr(self._len, self._ptr, needle._len, needle._ptr);
        token._ptr = self._ptr;
        token._len = ptr - self._ptr;
        if (ptr == self._ptr + self._len) {
            // Not found
            self._len = 0;
        } else {
            self._len -= token._len + needle._len;
            self._ptr = ptr + needle._len;
        }
        return token;
    }

    /*
     * @dev Splits the slice, setting `self` to everything after the first
     *      occurrence of `needle`, and returning everything before it. If
     *      `needle` does not occur in `self`, `self` is set to the empty slice,
     *      and the entirety of `self` is returned.
     * @param self The slice to split.
     * @param needle The text to search for in `self`.
     * @return The part of `self` up to the first occurrence of `delim`.
     */
    function split(
        slice memory self,
        slice memory needle
    ) internal pure returns (slice memory token) {
        split(self, needle, token);
    }

    /*
     * @dev Splits the slice, setting `self` to everything before the last
     *      occurrence of `needle`, and `token` to everything after it. If
     *      `needle` does not occur in `self`, `self` is set to the empty slice,
     *      and `token` is set to the entirety of `self`.
     * @param self The slice to split.
     * @param needle The text to search for in `self`.
     * @param token An output parameter to which the first token is written.
     * @return `token`.
     */
    function rsplit(
        slice memory self,
        slice memory needle,
        slice memory token
    ) internal pure returns (slice memory) {
        uint256 ptr =
            rfindPtr(self._len, self._ptr, needle._len, needle._ptr);
        token._ptr = ptr;
        token._len = self._len - (ptr - self._ptr);
        if (ptr == self._ptr) {
            // Not found
            self._len = 0;
        } else {
            self._len -= token._len + needle._len;
        }
        return token;
    }

    /*
     * @dev Splits the slice, setting `self` to everything before the last
     *      occurrence of `needle`, and returning everything after it. If
     *      `needle` does not occur in `self`, `self` is set to the empty slice,
     *      and the entirety of `self` is returned.
     * @param self The slice to split.
     * @param needle The text to search for in `self`.
     * @return The part of `self` after the last occurrence of `delim`.
     */
    function rsplit(
        slice memory self,
        slice memory needle
    ) internal pure returns (slice memory token) {
        rsplit(self, needle, token);
    }

    /*
     * @dev Counts the number of nonoverlapping occurrences of `needle` in `self`.
     * @param self The slice to search.
     * @param needle The text to search for in `self`.
     * @return The number of occurrences of `needle` found in `self`.
     */
    function count(
        slice memory self,
        slice memory needle
    ) internal pure returns (uint256 cnt) {
        uint256 ptr = findPtr(
            self._len, self._ptr, needle._len, needle._ptr
        ) + needle._len;
        while (ptr <= self._ptr + self._len) {
            cnt++;
            ptr = findPtr(
                self._len - (ptr - self._ptr),
                ptr,
                needle._len,
                needle._ptr
            ) + needle._len;
        }
    }

    /*
     * @dev Returns True if `self` contains `needle`.
     * @param self The slice to search.
     * @param needle The text to search for in `self`.
     * @return True if `needle` is found in `self`, false otherwise.
     */
    function contains(
        slice memory self,
        slice memory needle
    ) internal pure returns (bool) {
        return rfindPtr(
            self._len, self._ptr, needle._len, needle._ptr
        ) != self._ptr;
    }

    /*
     * @dev Returns a newly allocated string containing the concatenation of
     *      `self` and `other`.
     * @param self The first slice to concatenate.
     * @param other The second slice to concatenate.
     * @return The concatenation of the two strings.
     */
    function concat(
        slice memory self,
        slice memory other
    ) internal pure returns (string memory) {
        string memory ret = new string(self._len + other._len);
        uint256 retptr;
        assembly {
            retptr := add(ret, 32)
        }
        memcpy(retptr, self._ptr, self._len);
        memcpy(retptr + self._len, other._ptr, other._len);
        return ret;
    }

    /*
     * @dev Joins an array of slices, using `self` as a delimiter, returning a
     *      newly allocated string.
     * @param self The delimiter to use.
     * @param parts A list of slices to join.
     * @return A newly allocated string containing all the slices in `parts`,
     *         joined with `self`.
     */
    function join(
        slice memory self,
        slice[] memory parts
    ) internal pure returns (string memory) {
        if (parts.length == 0) {
            return "";
        }

        uint256 length = self._len * (parts.length - 1);
        for (uint256 i = 0; i < parts.length; i++) {
            length += parts[i]._len;
        }

        string memory ret = new string(length);
        uint256 retptr;
        assembly {
            retptr := add(ret, 32)
        }

        for (uint256 i = 0; i < parts.length; i++) {
            memcpy(retptr, parts[i]._ptr, parts[i]._len);
            retptr += parts[i]._len;
            if (i < parts.length - 1) {
                memcpy(retptr, self._ptr, self._len);
                retptr += self._len;
            }
        }

        return ret;
    }
}
