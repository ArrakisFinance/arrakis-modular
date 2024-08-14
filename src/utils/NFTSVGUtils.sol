// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.19;

library NFTSVGUtils {
    bytes16 private constant HEX_DIGITS = "0123456789abcdef";

    /// @notice Generates the logo for the NFT.
    function generateSVGLogo() public pure returns (string memory) {
        return string(
            abi.encodePacked(
                '<g id="text-logo" fill="white">',
                '<path d="M79.9663 439.232L57.0249 463.54L57.217 463.934H82.2822V458.758H70.5587L85.4821 442.936V463.934H91.9779V444.152C91.9779 437.754 84.3214 434.62 79.9692 439.232H79.9663Z"/>',
                '<path d="M225.085 463.928H205.16V458.119H226.554L208.558 449.852L208.307 449.691C205.646 448.006 204.307 445.656 205.18 442.303C206.027 439.045 208.659 437.464 211.729 437.464H231.163V443.281H211.145L227.732 451.178C230.903 452.751 232.598 455.316 231.723 458.804C230.903 462.099 228.327 463.92 225.099 463.92L225.091 463.928H225.085Z"/>',
                '<path d="M169.585 437.473H163.073V463.929H169.585V437.473Z"/><path d="M193.81 437.464H184.47L172.802 447.1C171.817 447.997 171.213 449.28 171.148 450.631C171.082 452.029 171.594 453.406 172.551 454.415L184.413 463.94H193.911L178.338 450.867L193.81 437.464Z"/>',
                '<path d="M202.296 437.473H195.783V463.937H202.296V437.473Z"/><path d="M101.976 463.937H95.4628V447.31C95.4628 441.878 99.7896 437.473 105.125 437.473H114.453V443.281H105.266C103.45 443.281 101.976 444.782 101.976 446.631V463.937Z"/>',
                '<path d="M121.878 463.937H115.366V447.31C115.366 441.878 119.692 437.473 125.027 437.473H134.356V443.281H125.169C123.353 443.281 121.878 444.782 121.878 446.631V463.937Z"/>',
                '<path d="M147.449 439.232L124.508 463.54L124.7 463.934H149.765V458.758H138.042L152.964 442.936V463.934H159.46V444.152C159.46 437.754 151.804 434.62 147.452 439.232H147.449Z"/>',
                '</g>'
            )
        );
    }

    /// @notice Converts an address to 2 string slices.
    /// @param addr_ address to convert to string.
    function addressToString(address addr_)
        public
        pure
        returns (string memory, string memory)
    {
        uint256 value = uint256(uint160(addr_));
        bytes memory s1 = new bytes(22);
        bytes memory s2 = new bytes(20);
        s1[0] = "0";
        s1[1] = "x";

        for (uint256 i = 19; i > 0; i--) {
            s2[i] = HEX_DIGITS[value & 0xf];
            value >>= 4;
        }
        s2[0] = HEX_DIGITS[value & 0xf];
        value >>= 4;

        for (uint256 i = 21; i > 1; i--) {
            s1[i] = HEX_DIGITS[value & 0xf];
            value >>= 4;
        }

        return (string(s1), string(s2));
    }

    /// @notice Converts uints to float strings with 4 decimal places.
    /// @param value_ uint to convert to string.
    /// @param decimals_ number of decimal places of the input value.
    function uintToFloatString(
        uint256 value_,
        uint8 decimals_
    ) public pure returns (string memory) {
        if (decimals_ < 5) {
            return _uintToString(value_);
        }

        uint256 scaleFactor = 10 ** decimals_;
        uint256 fraction =
            (value_ % scaleFactor) / 10 ** (decimals_ - 4);
        string memory fractionStr;
        if (fraction == 0) {
            fractionStr = "0000";
        } else if (fraction < 10) {
            fractionStr = string(
                abi.encodePacked("000", _uintToString(fraction))
            );
        } else if (fraction < 100) {
            fractionStr = string(
                abi.encodePacked("00", _uintToString(fraction))
            );
        } else if (fraction < 1000) {
            fractionStr =
                string(abi.encodePacked("0", _uintToString(fraction)));
        } else {
            fractionStr = _uintToString(fraction);
        }

        return string(
            abi.encodePacked(
                _uintToString(value_ / scaleFactor), ".", fractionStr
            )
        );
    }

    /// @notice Code borrowed form:
    /// https://github.com/transmissions11/solmate/blob/main/src/utils/LibString.sol
    ///
    /// @notice Converts uints to strings.
    /// @param value_ uint to convert to string.
    function _uintToString(uint256 value_)
        internal
        pure
        returns (string memory str)
    {
        /// @solidity memory-safe-assembly
        assembly {
            // The maximum value of a uint256 contains 78 digits (1 byte per digit), but we allocate 160 bytes
            // to keep the free memory pointer word aligned. We'll need 1 word for the length, 1 word for the
            // trailing zeros padding, and 3 other words for a max of 78 digits. In total: 5 * 32 = 160 bytes.
            let newFreeMemoryPointer := add(mload(0x40), 160)

            // Update the free memory pointer to avoid overriding our string.
            mstore(0x40, newFreeMemoryPointer)

            // Assign str to the end of the zone of newly allocated memory.
            str := sub(newFreeMemoryPointer, 32)

            // Clean the last word of memory it may not be overwritten.
            mstore(str, 0)

            // Cache the end of the memory to calculate the length later.
            let end := str

            // We write the string from rightmost digit to leftmost digit.
            // The following is essentially a do-while loop that also handles the zero case.
            // prettier-ignore
            for { let temp := value_ } 1 {} {
                // Move the pointer 1 byte to the left.
                str := sub(str, 1)

                // Write the character to the pointer.
                // The ASCII index of the '0' character is 48.
                mstore8(str, add(48, mod(temp, 10)))

                // Keep dividing temp until zero.
                temp := div(temp, 10)

                // prettier-ignore
                if iszero(temp) { break }
            }

            // Compute and cache the final total length of the string.
            let length := sub(end, str)

            // Move the pointer 32 bytes leftwards to make room for the length.
            str := sub(str, 32)

            // Store the string's length at the start of memory allocated for our string.
            mstore(str, length)
        }
    }
}
