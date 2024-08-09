// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.19;

import "@solady/contracts/utils/Base64.sol";
import {NFTSVGUtils} from "./NFTSVGUtils.sol";

/// @notice Parameters for generating the URI
struct SVGParams {
    address vault;
    uint256 amount0;
    uint256 amount1;
    uint8 decimals0;
    uint8 decimals1;
    string symbol0;
    string symbol1;
}

/// @dev Despite libraries can't inherit interfaces, we define the interface here
interface INFTSVG {
    
    /// @notice Checks if the contract is compliant with the NFTSVG interface
    function isNFTSVG() external pure returns (bool);

    /// @notice Generates a URI for a given vault
    /// @param params_ Parameters for generating the URI
    function generateVaultURI(SVGParams memory params_)
        external
        pure
        returns (string memory);

    /// @notice Generates a fallback URI for a given vault
    /// @param params_ Parameters for generating the URI    
    function generateFallbackURI(SVGParams memory params_)
        external
        pure
        returns (string memory);
}

contract NFTSVG is INFTSVG {

    /// @notice Checks if the contract is compliant with the NFTSVG interface
    function isNFTSVG() external pure returns (bool) {
        return true;
    }

    /// @notice Generates a URI for a given vault
    /// @param params_ Parameters for generating the URI
    function generateVaultURI(SVGParams memory params_)
        public
        pure
        returns (string memory)
    {
        string memory name = _generateName(params_);
        string memory description = _generateDescription(params_);
        string memory image =
            Base64.encode(bytes(_generateSVGImage(params_.vault)));

        return string(
            abi.encodePacked(
                "data:application/json;base64,",
                Base64.encode(
                    bytes(
                        abi.encodePacked(
                            '{"name":"',
                            name,
                            '", "description":"',
                            description,
                            '", "image": "',
                            "data:image/svg+xml;base64,",
                            image,
                            '"}'
                        )
                    )
                )
            )
        );
    }

    /// @notice Generates a fallback URI for a given vault
    /// @param params_ Parameters for generating the URI
    function generateFallbackURI(SVGParams memory params_)
        public
        pure
        returns (string memory)
    {
        string memory description = _generateDescription(params_);
        string memory image =
            Base64.encode(bytes(_generateSVGImage(params_.vault)));

        return string(
            abi.encodePacked(
                "data:application/json;base64,",
                Base64.encode(
                    bytes(
                        abi.encodePacked(
                            '{"name":" Arrakis Private Vault',
                            '", "description":"',
                            description,
                            '", "image": "',
                            "data:image/svg+xml;base64,",
                            image,
                            '"}'
                        )
                    )
                )
            )
        );
    }

    /// @notice Generates the name of the URI for a given vault
    /// @param params_ Parameters for generating the URI
    function _generateName(SVGParams memory params_)
        internal
        pure
        returns (string memory)
    {
        (string memory s1, string memory s2) =
            NFTSVGUtils.addressToString(params_.vault);
        return string(
            abi.encodePacked(
                "Arrakis ",
                params_.symbol0,
                "/",
                params_.symbol1,
                ": ",
                s1,
                s2
            )
        );
    }

    /// @notice Generates the description of the URI for a given vault
    /// @param params_ Parameters for generating the URI
    function _generateDescription(SVGParams memory params_)
        internal
        pure
        returns (string memory)
    {
        (string memory s1, string memory s2) =
            NFTSVGUtils.addressToString(params_.vault);

        return string(
            abi.encodePacked(
                unicode"⚠️ DO NOT TRANSFER TO UNTRUSTED PARTIES.",
                "\\n\\nThis NFT gives ownership of an Arrakis Modular Private Vault (",
                s1,
                s2,
                ") with an inventory of ",
                NFTSVGUtils.uintToFloatString(
                    params_.amount0, params_.decimals0
                ),
                " ",
                params_.symbol0,
                " and ",
                NFTSVGUtils.uintToFloatString(
                    params_.amount1, params_.decimals1
                ),
                " ",
                params_.symbol1,
                "."
            )
        );
    }

    /// @notice Generates the SVG image of the URI for a given vault
    /// @param vault_ The vault address represented by the NFT
    function _generateSVGImage(address vault_)
        internal
        pure
        returns (string memory svg)
    {
        return string(
            abi.encodePacked(
                '<svg width="290" height="500" viewBox="0 0 290 500" fill="none" xmlns="http://www.w3.org/2000/svg"><defs>',
                _generateSVGDefs(),
                "</defs>",
                _generateSVGFrame(),
                _generateSVGFront(),
                _generateSVGBack(vault_),
                "</svg>"
            )
        );
    }

    // #region auxiliary functions for generating the SVG image

    function _generateSVGDefs()
        internal
        pure
        returns (string memory)
    {
        return string(
            abi.encodePacked(
                '<linearGradient id="rect-gradient" gradientUnits="objectBoundingBox" x1="0" y1="0" x2=".75" y2="1.5">',
                '<stop offset="0"><animate attributeName="stop-color" values="#050302;#050302;#7D3711;#7D3711;#DC601D;#FFA760;#FFA760;#7D3711;#7D3711;#050302;#050302;#050302;#050302;" dur="30s" repeatCount="indefinite"></animate></stop>',
                '<stop offset=".33"><animate attributeName="stop-color" values="#050302;#050302;#7D3711;#FFA760;#FFA760;#F56A20;#DC601D;#FA7C40;#7D3711;#7D3711;#050302;#050302;#050302;" dur="30s" repeatCount="indefinite"></animate></stop>',
                '<stop offset=".67"><animate attributeName="stop-color" values="#050302;#050302;#050302;#7D3711;#DC601D;#FFA760;#FFA760;#F56A20;#DC601D;#7D3711;#E89857;#050302;#050302;" dur="30s" repeatCount="indefinite"></animate></stop>',
                '<stop offset="1"><animate attributeName="stop-color" values="#050302;#050302;#050302;#050302;#7D3711;#DC601D;#DC601D;#FA7C40;#FA7C40;#DC601D;#E89857;#050302;#050302;" dur="30s" repeatCount="indefinite"></animate></stop>',
                '<animateTransform attributeName="gradientTransform" type="translate" from="-.8 -.8" to=".8 .8" dur="30s" repeatCount="indefinite" /></linearGradient>',
                '<linearGradient id="tail-gradient" x1="183.99" y1="59.2903" x2="171.409" y2="178.815" gradientUnits="userSpaceOnUse"><stop stop-color="white"/><stop offset="1" stop-color="white" stop-opacity="0"/></linearGradient>',
                _generateSVGMasks()
            )
        );
    }

    function _generateSVGMasks()
        internal
        pure
        returns (string memory)
    {
        return string(
            abi.encodePacked(
                '<mask id="waves-mask"><rect x="0" y="0" width="100%" height="100%" fill="white" />',
                '<g style="scale(3)"><linearGradient id="waves2" x1="0" x2="1" y1="0" y2="0"><stop stop-color="#000000" offset="0"></stop><stop stop-color="#000000" offset="1"></stop></linearGradient>',
                '<path d="" fill="black" opacity="0.33"><animate attributeName="d" dur="8s" repeatCount="indefinite" keyTimes="0;0.333;0.667;1" calcMode="spline" keySplines="0.5 0 0.5 1;0.5 0 0.5 1;0.5 0 0.5 1" begin="0s" values="M0 0L0 279.72Q72.50 95.90 145 80.31T290 -2.87L290 0Z;M0 0L0 178.34Q72.50 66.44 145 50.16T290 -49.50L290 0Z;M0 0L0 244.09Q72.50 178.37 145 151.37T290 -124.25L290 0Z;M0 0L0 279.72Q72.50 95.90 145 80.31T290 -2.87L290 0Z"></animate></path>'
                '<path d="" fill="black" opacity="0.33"><animate attributeName="d" dur="8s" repeatCount="indefinite" keyTimes="0;0.333;0.667;1" calcMode="spline" keySplines="0.5 0 0.5 1;0.5 0 0.5 1;0.5 0 0.5 1" begin="-4.166666666666667s" values="M0 0L0 258.07Q72.50 130.78 145 98.80T290 -39.43L290 0Z;M0 0L0 242.23Q72.50 39.39 145 16.94T290 -28.59L290 0Z;M0 0L0 224.02Q72.50 53.87 145 31.25T290 -65.65L290 0Z;M0 0L0 258.07Q72.50 130.78 145 98.80T290 -39.43L290 0Z"></animate></path>',
                "</g></mask>",
                '<mask id="inner_rect_mask" style="mask-type:alpha" maskUnits="userSpaceOnUse" x="10.5" y="10.5" width="269" height="479"><rect x="10.5" y="10.5" width="269" height="479" rx="23.5" fill="#D9D9D9"/></mask>'
            )
        );
    }

    function _generateSVGFrame()
        internal
        pure
        returns (string memory)
    {
        return string(
            abi.encodePacked(
                '<rect width="290" height="500" rx="24" fill="black"/><rect width="290" height="500" rx="24" fill="url(#rect-gradient)"/>',
                '<g id="waves" mask="url(#inner_rect_mask)"><g mask="url(#waves-mask)"><g style="transform:translate(145.0px,250.0px) scale(-1,1) translate(-145.0px,-250.0px)"><linearGradient id="waves1" x1="0" x2="1" y1="0" y2="0"><stop stop-color="#ffffff" offset="0"></stop><stop stop-color="#ffffff" offset="1"></stop></linearGradient>',
                '<path d="" fill="white" opacity="0.033"><animate attributeName="d" dur="15s" repeatCount="indefinite" keyTimes="0;0.333;0.667;1" calcMode="spline" keySplines="0.5 0 0.5 1;0.5 0 0.5 1;0.5 0 0.5 1" begin="0s" values="M0 0L0 225.85Q72.50 535.81 145 487.99T290 618.39L290 0Z;M0 0L0 62.93Q72.50 363.50 145 349.64T290 259.60L290 0Z;M0 0L0 215.10Q72.50 239.83 145 212.50T290 525.33L290 0Z;M0 0L0 225.85Q72.50 535.81 145 487.99T290 618.39L290 0Z"></animate></path>',
                '<path d="" fill="white" opacity="0.033"><animate attributeName="d" dur="15s" repeatCount="indefinite" keyTimes="0;0.333;0.667;1" calcMode="spline" keySplines="0.5 0 0.5 1;0.5 0 0.5 1;0.5 0 0.5 1" begin="-3.7037037037037037s" values="M0 0L0 -139.57Q72.50 522.50 145 485.95T290 463.92L290 0Z;M0 0L0 206.11Q72.50 251.85 145 229.63T290 357.17L290 0Z;M0 0L0 -112.70Q72.50 427.35 145 404.61T290 683.65L290 0Z;M0 0L0 -139.57Q72.50 522.50 145 485.95T290 463.92L290 0Z"></animate></path>',
                '<path d="" fill="white" opacity="0.033"><animate attributeName="d" dur="15s" repeatCount="indefinite" keyTimes="0;0.333;0.667;1" calcMode="spline" keySplines="0.5 0 0.5 1;0.5 0 0.5 1;0.5 0 0.5 1" begin="-7.407407407407407s" values="M0 0L0 120.25Q72.50 269.55 145 248.41T290 380.02L290 0Z;M0 0L0 -35.24Q72.50 502.96 145 476.67T290 570.38L290 0Z;M0 0L0 -1.04Q72.50 515.48 145 487.93T290 370.53L290 0Z;M0 0L0 120.25Q72.50 269.55 145 248.41T290 380.02L290 0Z"></animate></path>',
                '</g></g></g><rect x="10.5" y="10.5" width="269" height="479" rx="23.5" stroke="white" stroke-opacity="0.33" stroke-width="2"/>',
                NFTSVGUtils.generateSVGLogo(),
                _generateSVGDunes()
            )
        );
    }

    function _generateSVGDunes()
        internal
        pure
        returns (string memory)
    {
        return string(
            abi.encodePacked(
                '<g id="dunes" transform="translate(0 33)"><g mask="url(#inner_rect_mask)">',
                '<path d="M0.5 355.5C178.5 330.5 153.023 310.248 108 316C76.5 320.024 86.3739 305.5 106 294.5C135.856 277.767 137.872 272.876 130.5 267.5M130.5 267.5C73.5966 287.906 40.9646 300.008 0.5 305.5M130.5 267.5C169.496 271.232 185.689 274.308 210.5 280.5C249.139 288.743 267.721 291.842 290 292" stroke="white" stroke-opacity="0.33"/>',
                '<path d="M0.5 262.5C0.5 262.5 48.5 255 102 253C155.5 251 183 241.5 189.5 235.227M189.5 235.227C222.621 246.569 191.696 261.647 163.5 271M189.5 235.227C198.96 233.427 225.5 242.827 244.5 246.329C273.228 251.623 280.179 251.674 291 251.263" stroke="white" stroke-opacity="0.33"/>',
                "</g></g>"
            )
        );
    }

    function _generateSVGFront()
        internal
        pure
        returns (string memory)
    {
        return string(
            abi.encodePacked(
                '<g id="front" fill="white">',
                '<animate attributeName="opacity" values="1;1;1;1;1;1;1;1;0;0;0;0;0;1" dur="30s" repeatCount="indefinite"/>',
                '<path d="M171.691 152.953L134.814 127.595L114.918 136.159C114.776 136.241 114.61 136.274 114.447 136.253C114.284 136.231 114.133 136.157 114.017 136.041C113.901 135.924 113.826 135.773 113.805 135.61C113.783 135.447 113.816 135.282 113.899 135.139L122.189 115.243L113.899 95.3515C113.814 95.2091 113.78 95.0429 113.8 94.8788C113.821 94.7146 113.895 94.562 114.012 94.4448C114.129 94.3276 114.281 94.2525 114.445 94.2313C114.609 94.2101 114.775 94.244 114.918 94.3276L134.814 102.631L154.706 94.3276C154.849 94.246 155.015 94.2137 155.178 94.2356C155.341 94.2575 155.492 94.3324 155.609 94.4488C155.725 94.5651 155.8 94.7165 155.822 94.8796C155.844 95.0427 155.811 95.2085 155.73 95.3515L147.439 115.243L172.524 152.146C172.631 152.257 172.69 152.405 172.687 152.559C172.685 152.713 172.621 152.859 172.511 152.966C172.401 153.073 172.252 153.132 172.098 153.129C171.944 153.127 171.798 153.064 171.691 152.953Z"/>',
                '<g id="sand-worm">',
                '<path opacity="0.6" d="M142.289 53.0082C140.09 52.9128 136.103 53.6677 133.283 54.2794C133.064 54.3278 132.866 54.445 132.718 54.6138C132.57 54.7826 132.479 54.9942 132.46 55.2178C132.441 55.4415 132.493 55.6655 132.61 55.8572C132.727 56.0489 132.902 56.1983 133.109 56.2837L135.578 57.2989C135.578 57.2989 139.023 55.3423 142.289 53.0082Z"/>',
                '<path opacity="0.6" d="M135.257 65.8977C137.673 65.9238 140.866 65.8977 142.727 65.7546C140.155 64.453 136.389 62.7654 136.389 62.7654L134.653 63.9801C134.47 64.1087 134.332 64.2923 134.26 64.5044C134.188 64.7165 134.186 64.9461 134.253 65.1598C134.32 65.3734 134.454 65.5602 134.634 65.6929C134.814 65.8256 135.033 65.8973 135.257 65.8977Z"/>',
                '<path d="M211.14 112.992C207.492 82.4446 182.151 57.377 151.977 53.7805C147.539 53.2512 143.569 53.0646 142.463 53.0082C142.038 52.9841 141.619 53.1067 141.274 53.3553C139.296 54.761 137.152 56.236 135.061 57.6547C134.675 57.9172 134.365 58.276 134.16 58.6956C133.956 59.1152 133.865 59.5809 133.896 60.0466C133.927 60.5123 134.079 60.9618 134.338 61.3504C134.596 61.739 134.952 62.0534 135.369 62.2621C137.773 63.4595 140.293 64.7177 142.003 65.5767C142.309 65.7282 142.651 65.7941 142.992 65.7676C143.46 65.7286 148.91 65.8804 150.571 66.0713C167.925 68.0236 184.168 78.1192 193.565 92.8916C212.355 121.959 202.511 160.216 174.433 178.012C173.973 178.303 173.487 178.598 172.979 178.88C171.292 179.851 172.628 182.428 174.381 181.569C174.958 181.287 175.522 180.992 176.068 180.702C199.908 167.339 214.984 140.636 211.14 112.992Z" fill="url(#tail-gradient)"/>',
                '<animateTransform attributeName="transform" attributeType="XML" type="rotate" from="360 140 120" to="0 140 120" dur="25s" repeatCount="indefinite"/>',
                "</g></g>"
            )
        );
    }

    function _generateSVGBack(address vault_)
        internal
        pure
        returns (string memory)
    {
        (string memory s1, string memory s2) =
            NFTSVGUtils.addressToString(vault_);
        return string(
            abi.encodePacked(
                '<g id="back" attributeName="opacity" values="0;" fill="white" font-family="system-ui" font-weight="bold" text-anchor="middle">',
                '<animate attributeName="opacity" values="0;0;0;0;0;0;0;0;0;1;1;1;0;0" dur="30s" repeatCount="indefinite"/>',
                '<text font-size="18" x="145" y="75">This NFT gives ownership</text><text font-size="18" x="145" y="100">rights of a private vault</text>',
                '<g opacity="0.67"><text font-size="13" font-weight="normal" x="145" y="127.5">Be careful when transferring</text>',
                '<text font-size="13" font-weight="normal" x="145" y="172.5">Vault ID</text>',
                '</g><text x="145" y="200">',
                s1,
                '</text><text x="145" y="222.5">',
                s2,
                "</text></g>"
            )
        );
    }

    // #endregion auxiliary functions for generating the SVG image
}
