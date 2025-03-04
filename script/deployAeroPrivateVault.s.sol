// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {console} from "forge-std/console.sol";
import {CreateXScript} from "./deployment/CreateXScript.sol";

import {NATIVE_COIN, TEN_PERCENT} from "../src/constants/CArrakis.sol";
import {IOracleWrapper} from "../src/interfaces/IOracleWrapper.sol";
import {IAerodromeStandardModulePrivate} from
    "../src/interfaces/IAerodromeStandardModulePrivate.sol";
import {IArrakisMetaVaultFactory} from
    "../src/interfaces/IArrakisMetaVaultFactory.sol";

// #region enums.
enum OracleDeployment {
    UniV3Oracle,
    ChainlinkOracleWrapper,
    DeployedChainlinkOracleWrapper
}
// #endregion enums.

// IMPORTANT !!! Fill in / check these sensitive varaibles before running script !!!

address constant token0 = 0x4200000000000000000000000000000000000006;
address constant token1 = 0x9a33406165f562E16C3abD82fd1185482E01b49a;
int24 constant tickSpacing = 200;

bytes32 constant salt =
    keccak256(abi.encode("Mainnet WETH/TALENT Aerodrome private vault v1"));
address constant vaultOwner =
    0x81a1e7F34b9bABf172087cF5df8A4DF6500e9d4d;
uint256 constant init0 = 1;
uint256 constant init1 = 1;
uint24 constant maxSlippage = TEN_PERCENT / 2;

uint24 constant maxDeviation = TEN_PERCENT;
uint256 constant cooldownPeriod = 60;
address constant executor = 0xe012b59a8fC2D18e2C8943106a05C2702640440B;
address constant stratAnnouncer =
    0x81a1e7F34b9bABf172087cF5df8A4DF6500e9d4d;

address constant upgreadableBeacon = 0x8Dd906EcF9D434A3fBf2d60a14Fbf73d14d4Ea6e;

address constant factory = 0x820FB8127a689327C863de8433278d6181123982;
address constant pool = 0x346eDb1aAa704dF6dDbfc604724AAFcdC12b2fed;
address constant aeroReceiver = 0x25CF23B54e25daaE3fe9989a74050b953A343823;

bytes constant creationCodeUniV3Oracle = bytes("0x60c060405234801561001057600080fd5b506040516115a63803806115a683398101604081905261002f916100c5565b6001600160a01b03821661006f5760405162461bcd60e51b81526020600482015260026024820152615a4160f01b60448201526064015b60405180910390fd5b610e108162ffffff1611156100aa5760405162461bcd60e51b81526020600482015260016024820152601560fa1b6044820152606401610066565b6001600160a01b0390911660805262ffffff1660a052610113565b600080604083850312156100d857600080fd5b82516001600160a01b03811681146100ef57600080fd5b602084015190925062ffffff8116811461010857600080fd5b809150509250929050565b60805160a0516114546101526000396000818160a7015281816101230152610174015260008181605601528181610102015261015301526114546000f3fe608060405234801561001057600080fd5b506004361061004c5760003560e01c806316f0115b1461005157806326d89545146100a2578063a941ada9146100dd578063e84b8fe5146100f3575b600080fd5b6100787f000000000000000000000000000000000000000000000000000000000000000081565b60405173ffffffffffffffffffffffffffffffffffffffff90911681526020015b60405180910390f35b6100c97f000000000000000000000000000000000000000000000000000000000000000081565b60405162ffffff9091168152602001610099565b6100e56100fb565b604051908152602001610099565b6100e561014c565b60006101477f00000000000000000000000000000000000000000000000000000000000000007f0000000000000000000000000000000000000000000000000000000000000000610198565b905090565b60006101477f00000000000000000000000000000000000000000000000000000000000000007f00000000000000000000000000000000000000000000000000000000000000006103a2565b6000808373ffffffffffffffffffffffffffffffffffffffff1663d21220a76040518163ffffffff1660e01b8152600401602060405180830381865afa1580156101e6573d6000803e3d6000fd5b505050506040513d601f19601f8201168201806040525081019061020a9190610d6c565b90506000610218858561059f565b73ffffffffffffffffffffffffffffffffffffffff1690506fffffffffffffffffffffffffffffffff81116102f4576102ed78010000000000000000000000000000000000000000000000008373ffffffffffffffffffffffffffffffffffffffff1663313ce5676040518163ffffffff1660e01b8152600401602060405180830381865afa1580156102af573d6000803e3d6000fd5b505050506040513d601f19601f820116820180604052508101906102d39190610d9f565b6102de90600a610f09565b6102e88480610f18565b610647565b925061039a565b6103977001000000000000000000000000000000008373ffffffffffffffffffffffffffffffffffffffff1663313ce5676040518163ffffffff1660e01b8152600401602060405180830381865afa158015610354573d6000803e3d6000fd5b505050506040513d601f19601f820116820180604052508101906103789190610d9f565b61038390600a610f09565b6102e8848568010000000000000000610647565b92505b505092915050565b6000808373ffffffffffffffffffffffffffffffffffffffff16630dfe16816040518163ffffffff1660e01b8152600401602060405180830381865afa1580156103f0573d6000803e3d6000fd5b505050506040513d601f19601f820116820180604052508101906104149190610d6c565b90506000610422858561059f565b73ffffffffffffffffffffffffffffffffffffffff1690506fffffffffffffffffffffffffffffffff81116104f7576102ed61045e8280610f18565b8373ffffffffffffffffffffffffffffffffffffffff1663313ce5676040518163ffffffff1660e01b8152600401602060405180830381865afa1580156104a9573d6000803e3d6000fd5b505050506040513d601f19601f820116820180604052508101906104cd9190610d9f565b6104d890600a610f09565b7801000000000000000000000000000000000000000000000000610647565b61039761050e828368010000000000000000610647565b8373ffffffffffffffffffffffffffffffffffffffff1663313ce5676040518163ffffffff1660e01b8152600401602060405180830381865afa158015610559573d6000803e3d6000fd5b505050506040513d601f19601f8201168201806040525081019061057d9190610d9f565b61058890600a610f09565b700100000000000000000000000000000000610647565b60008162ffffff1660000361062c578273ffffffffffffffffffffffffffffffffffffffff16633850c7bd6040518163ffffffff1660e01b815260040160e060405180830381865afa1580156105f9573d6000803e3d6000fd5b505050506040513d601f19601f8201168201806040525081019061061d9190610f67565b50949550610641945050505050565b61063e6106398484610719565b6108a6565b90505b92915050565b600080807fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff8587098587029250828110838203039150508060000361069e576000841161069357600080fd5b508290049050610712565b8084116106aa57600080fd5b600084868809851960019081018716968790049682860381900495909211909303600082900391909104909201919091029190911760038402600290811880860282030280860282030280860282030280860282030280860282030280860290910302029150505b9392505050565b604080516002808252606082018352600092839291906020830190803683370190505090508262ffffff168160008151811061075757610757611031565b602002602001019063ffffffff16908163ffffffff168152505060008160018151811061078657610786611031565b63ffffffff909216602092830291909101909101526040517f883bdbfd00000000000000000000000000000000000000000000000000000000815260009073ffffffffffffffffffffffffffffffffffffffff86169063883bdbfd906107f0908590600401611060565b600060405180830381865afa15801561080d573d6000803e3d6000fd5b505050506040513d6000823e601f3d9081017fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe01682016040526108539190810190611191565b5090508362ffffff168160008151811061086f5761086f611031565b60200260200101518260018151811061088a5761088a611031565b602002602001015161089c919061125d565b61039791906112f4565b60008060008360020b126108bd578260020b6108ca565b8260020b6108ca90611368565b90506108f57ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff276186113a0565b60020b811115610965576040517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820152600160248201527f5400000000000000000000000000000000000000000000000000000000000000604482015260640160405180910390fd5b6000816001166000036109895770010000000000000000000000000000000061099b565b6ffffcb933bd6fad37aa2d162d1a5940015b70ffffffffffffffffffffffffffffffffff16905060028216156109da5760806109d5826ffff97272373d413259a46990580e213a610f18565b901c90505b6004821615610a045760806109ff826ffff2e50f5f656932ef12357cf3c7fdcc610f18565b901c90505b6008821615610a2e576080610a29826fffe5caca7e10e4e61c3624eaa0941cd0610f18565b901c90505b6010821615610a58576080610a53826fffcb9843d60f6159c9db58835c926644610f18565b901c90505b6020821615610a82576080610a7d826fff973b41fa98c081472e6896dfb254c0610f18565b901c90505b6040821615610aac576080610aa7826fff2ea16466c96a3843ec78b326b52861610f18565b901c90505b6080821615610ad6576080610ad1826ffe5dee046a99a2a811c461f1969c3053610f18565b901c90505b610100821615610b01576080610afc826ffcbe86c7900a88aedcffc83b479aa3a4610f18565b901c90505b610200821615610b2c576080610b27826ff987a7253ac413176f2b074cf7815e54610f18565b901c90505b610400821615610b57576080610b52826ff3392b0822b70005940c7a398e4b70f3610f18565b901c90505b610800821615610b82576080610b7d826fe7159475a2c29b7443b29c7fa6e889d9610f18565b901c90505b611000821615610bad576080610ba8826fd097f3bdfd2022b8845ad8f792aa5825610f18565b901c90505b612000821615610bd8576080610bd3826fa9f746462d870fdf8a65dc1f90e061e5610f18565b901c90505b614000821615610c03576080610bfe826f70d869a156d2a1b890bb3df62baf32f7610f18565b901c90505b618000821615610c2e576080610c29826f31be135f97d08fd981231505542fcfa6610f18565b901c90505b62010000821615610c5a576080610c55826f09aa508b5b7a84e1c677de54f3e99bc9610f18565b901c90505b62020000821615610c85576080610c80826e5d6af8dedb81196699c329225ee604610f18565b901c90505b62040000821615610caf576080610caa826d2216e584f5fa1ea926041bedfe98610f18565b901c90505b62080000821615610cd7576080610cd2826b048a170391f7dc42444e8fa2610f18565b901c90505b60008460020b1315610d1057610d0d817fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff6113de565b90505b610d1f640100000000826113f2565b15610d2b576001610d2e565b60005b610d3f9060ff16602083901c611406565b949350505050565b73ffffffffffffffffffffffffffffffffffffffff81168114610d6957600080fd5b50565b600060208284031215610d7e57600080fd5b815161071281610d47565b805160ff81168114610d9a57600080fd5b919050565b600060208284031215610db157600080fd5b61063e82610d89565b7f4e487b7100000000000000000000000000000000000000000000000000000000600052601160045260246000fd5b600181815b80851115610e4257817fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff04821115610e2857610e28610dba565b80851615610e3557918102915b93841c9390800290610dee565b509250929050565b600082610e5957506001610641565b81610e6657506000610641565b8160018114610e7c5760028114610e8657610ea2565b6001915050610641565b60ff841115610e9757610e97610dba565b50506001821b610641565b5060208310610133831016604e8410600b8410161715610ec5575081810a610641565b610ecf8383610de9565b807fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff04821115610f0157610f01610dba565b029392505050565b600061063e60ff841683610e4a565b6000817fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff0483118215151615610f5057610f50610dba565b500290565b805161ffff81168114610d9a57600080fd5b600080600080600080600060e0888a031215610f8257600080fd5b8751610f8d81610d47565b8097505060208801518060020b8114610fa557600080fd5b9550610fb360408901610f55565b9450610fc160608901610f55565b9350610fcf60808901610f55565b9250610fdd60a08901610d89565b915060c08801518015158114610ff257600080fd5b8091505092959891949750929550565b7f4e487b7100000000000000000000000000000000000000000000000000000000600052604160045260246000fd5b7f4e487b7100000000000000000000000000000000000000000000000000000000600052603260045260246000fd5b6020808252825182820181905260009190848201906040850190845b8181101561109e57835163ffffffff168352928401929184019160010161107c565b50909695505050505050565b604051601f82017fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe016810167ffffffffffffffff811182821017156110f1576110f1611002565b604052919050565b600067ffffffffffffffff82111561111357611113611002565b5060051b60200190565b600082601f83011261112e57600080fd5b8151602061114361113e836110f9565b6110aa565b82815260059290921b8401810191818101908684111561116257600080fd5b8286015b8481101561118657805161117981610d47565b8352918301918301611166565b509695505050505050565b600080604083850312156111a457600080fd5b825167ffffffffffffffff808211156111bc57600080fd5b818501915085601f8301126111d057600080fd5b815160206111e061113e836110f9565b82815260059290921b840181019181810190898411156111ff57600080fd5b948201945b8386101561122d5785518060060b811461121e5760008081fd5b82529482019490820190611204565b9188015191965090935050508082111561124657600080fd5b506112538582860161111d565b9150509250929050565b60008160060b8360060b60008112817fffffffffffffffffffffffffffffffffffffffffffffffffff80000000000000018312811516156112a0576112a0610dba565b81667fffffffffffff0183138116156112bb576112bb610dba565b5090039392505050565b7f4e487b7100000000000000000000000000000000000000000000000000000000600052601260045260246000fd5b60008160060b8360060b8061130b5761130b6112c5565b7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff81147fffffffffffffffffffffffffffffffffffffffffffffffffff800000000000008314161561135f5761135f610dba565b90059392505050565b60007f8000000000000000000000000000000000000000000000000000000000000000820361139957611399610dba565b5060000390565b60008160020b7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffff80000081036113d5576113d5610dba565b60000392915050565b6000826113ed576113ed6112c5565b500490565b600082611401576114016112c5565b500690565b6000821982111561141957611419610dba565b50019056fea2646970667358221220b58f45cdb20ce4ec6fc70d87f74ffe2df4003b4c71faa05f7c5a3646adb1d3f164736f6c634300080d0033");
bytes constant creationCode_chainlinkOracleWrapper = bytes(
    "0x6101206040523480156200001257600080fd5b506040516200128c3803806200128c833981016040819052620000359162000132565b6200004033620000b3565b6001600160a01b038416620000805760405162461bcd60e51b81526020600482015260026024820152615a4160f01b604482015260640160405180910390fd5b60ff9586166080529390941660a0526001600160a01b0391821660c0521660e052600191909155151561010052620001b2565b600080546001600160a01b038381166001600160a01b0319831681178455604051919092169283917f8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e09190a35050565b805160ff811681146200011557600080fd5b919050565b80516001600160a01b03811681146200011557600080fd5b60008060008060008060c087890312156200014c57600080fd5b620001578762000103565b9550620001676020880162000103565b945062000177604088016200011a565b935062000187606088016200011a565b92506080870151915060a08701518015158114620001a457600080fd5b809150509295509295509295565b60805160a05160c05160e051610100516110426200024a600039600081816104b5015261080801526000818161019c015281816102330152818161058b0152610ab10152600081816101320152818161027701528181610424015281816105cf015261077701526000818160d30152818161084d01526108840152600081816101cb015281816104f9015261055601526110426000f3fe608060405234801561001057600080fd5b50600436106100c95760003560e01c8063a726470511610081578063e84b8fe51161005b578063e84b8fe5146101ed578063ed6308f7146101f5578063f2fde38b1461020857600080fd5b8063a726470514610197578063a941ada9146101be578063b31ac6e2146101c657600080fd5b8063715018a6116100b2578063715018a614610123578063741bef1a1461012d5780638da5cb5b1461017957600080fd5b80630b77884d146100ce5780633cccb49c1461010c575b600080fd5b6100f57f000000000000000000000000000000000000000000000000000000000000000081565b60405160ff90911681526020015b60405180910390f35b61011560015481565b604051908152602001610103565b61012b61021b565b005b6101547f000000000000000000000000000000000000000000000000000000000000000081565b60405173ffffffffffffffffffffffffffffffffffffffff9091168152602001610103565b60005473ffffffffffffffffffffffffffffffffffffffff16610154565b6101547f000000000000000000000000000000000000000000000000000000000000000081565b61011561022f565b6100f57f000000000000000000000000000000000000000000000000000000000000000081565b610115610587565b61012b610203366004610d8f565b6108aa565b61012b610216366004610da8565b6108ff565b6102236109b6565b61022d6000610a37565b565b60007f000000000000000000000000000000000000000000000000000000000000000073ffffffffffffffffffffffffffffffffffffffff161561027557610275610aac565b7f000000000000000000000000000000000000000000000000000000000000000073ffffffffffffffffffffffffffffffffffffffff1663feaf968c6040518163ffffffff1660e01b815260040160a060405180830381865afa92505050801561031a575060408051601f3d9081017fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe016820190925261031791810190610dfd565b60015b6103ab576040517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820152602860248201527f436861696e4c696e6b4f7261636c653a20707269636520666565642063616c6c60448201527f206661696c65642e00000000000000000000000000000000000000000000000060648201526084015b60405180910390fd5b6001546103b88342610e7c565b1115610420576040517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820152601a60248201527f436861696e4c696e6b4f7261636c653a206f757464617465642e00000000000060448201526064016103a2565b60007f000000000000000000000000000000000000000000000000000000000000000073ffffffffffffffffffffffffffffffffffffffff1663313ce5676040518163ffffffff1660e01b8152600401602060405180830381865afa15801561048d573d6000803e3d6000fd5b505050506040513d601f19601f820116820180604052508101906104b19190610e93565b90507f00000000000000000000000000000000000000000000000000000000000000006105455761053a61052d6104e9836002610eb6565b6104f490600a610ffd565b61051f7f0000000000000000000000000000000000000000000000000000000000000000600a610ffd565b61052889610c4d565b610cbd565b600161052884600a610ffd565b965050505050505090565b61053a61055186610c4d565b61057c7f0000000000000000000000000000000000000000000000000000000000000000600a610ffd565b61052884600a610ffd565b60007f000000000000000000000000000000000000000000000000000000000000000073ffffffffffffffffffffffffffffffffffffffff16156105cd576105cd610aac565b7f000000000000000000000000000000000000000000000000000000000000000073ffffffffffffffffffffffffffffffffffffffff1663feaf968c6040518163ffffffff1660e01b815260040160a060405180830381865afa925050508015610672575060408051601f3d9081017fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe016820190925261066f91810190610dfd565b60015b6106fe576040517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820152602860248201527f436861696e4c696e6b4f7261636c653a20707269636520666565642063616c6c60448201527f206661696c65642e00000000000000000000000000000000000000000000000060648201526084016103a2565b60015461070b8342610e7c565b1115610773576040517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820152601a60248201527f436861696e4c696e6b4f7261636c653a206f757464617465642e00000000000060448201526064016103a2565b60007f000000000000000000000000000000000000000000000000000000000000000073ffffffffffffffffffffffffffffffffffffffff1663313ce5676040518163ffffffff1660e01b8152600401602060405180830381865afa1580156107e0573d6000803e3d6000fd5b505050506040513d601f19601f820116820180604052508101906108049190610e93565b90507f0000000000000000000000000000000000000000000000000000000000000000156108735761053a61052d61083d836002610eb6565b61084890600a610ffd565b61051f7f0000000000000000000000000000000000000000000000000000000000000000600a610ffd565b61053a61087f86610c4d565b61057c7f0000000000000000000000000000000000000000000000000000000000000000600a610ffd565b6108b26109b6565b600180549082905560408051308152602081018390529081018390527f4be25d0984bef9e8c2ab124bd255b2fd9a7904b5c81e079a73ef7586b34a36ca9060600160405180910390a15050565b6109076109b6565b73ffffffffffffffffffffffffffffffffffffffff81166109aa576040517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820152602660248201527f4f776e61626c653a206e6577206f776e657220697320746865207a65726f206160448201527f646472657373000000000000000000000000000000000000000000000000000060648201526084016103a2565b6109b381610a37565b50565b60005473ffffffffffffffffffffffffffffffffffffffff16331461022d576040517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820181905260248201527f4f776e61626c653a2063616c6c6572206973206e6f7420746865206f776e657260448201526064016103a2565b6000805473ffffffffffffffffffffffffffffffffffffffff8381167fffffffffffffffffffffffff0000000000000000000000000000000000000000831681178455604051919092169283917f8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e09190a35050565b6000807f000000000000000000000000000000000000000000000000000000000000000073ffffffffffffffffffffffffffffffffffffffff1663feaf968c6040518163ffffffff1660e01b815260040160a060405180830381865afa158015610b1a573d6000803e3d6000fd5b505050506040513d601f19601f82011682018060405250810190610b3e9190610dfd565b5050925092505081600014610baf576040517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820152601f60248201527f436861696e4c696e6b4f7261636c653a2073657175656e63657220646f776e0060448201526064016103a2565b610e10610bbc8242610e7c565b11610c49576040517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820152602660248201527f436861696e4c696e6b4f7261636c653a20677261636520706572696f64206e6f60448201527f74206f766572000000000000000000000000000000000000000000000000000060648201526084016103a2565b5050565b600080821215610cb9576040517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820181905260248201527f53616665436173743a2076616c7565206d75737420626520706f73697469766560448201526064016103a2565b5090565b600080807fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff85870985870292508281108382030391505080600003610d145760008411610d0957600080fd5b508290049050610d88565b808411610d2057600080fd5b600084868809851960019081018716968790049682860381900495909211909303600082900391909104909201919091029190911760038402600290811880860282030280860282030280860282030280860282030280860282030280860290910302029150505b9392505050565b600060208284031215610da157600080fd5b5035919050565b600060208284031215610dba57600080fd5b813573ffffffffffffffffffffffffffffffffffffffff81168114610d8857600080fd5b805169ffffffffffffffffffff81168114610df857600080fd5b919050565b600080600080600060a08688031215610e1557600080fd5b610e1e86610dde565b9450602086015193506040860151925060608601519150610e4160808701610dde565b90509295509295909350565b7f4e487b7100000000000000000000000000000000000000000000000000000000600052601160045260246000fd5b600082821015610e8e57610e8e610e4d565b500390565b600060208284031215610ea557600080fd5b815160ff81168114610d8857600080fd5b600060ff821660ff84168160ff0481118215151615610ed757610ed7610e4d565b029392505050565b600181815b80851115610f3857817fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff04821115610f1e57610f1e610e4d565b80851615610f2b57918102915b93841c9390800290610ee4565b509250929050565b600082610f4f57506001610ff7565b81610f5c57506000610ff7565b8160018114610f725760028114610f7c57610f98565b6001915050610ff7565b60ff841115610f8d57610f8d610e4d565b50506001821b610ff7565b5060208310610133831016604e8410600b8410161715610fbb575081810a610ff7565b610fc58383610edf565b807fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff04821115610ed757610ed7610e4d565b92915050565b6000610d8860ff841683610f4056fea26469706673582212205aa8244867135c60c85382684fca646f2d27ed11085b3f98deb50f69e21ac8b564736f6c634300080d0033"
);

OracleDeployment constant oracleDeployment =
    OracleDeployment.UniV3Oracle;

uint8 constant token0Decimals = 18;
uint8 constant token1Decimals = 18;
address constant priceFeed = address(0);
address constant sequencerUpTimeFeed = address(0);
uint256 constant outdated = 0;
bool constant isPriceFeedInversed = false;

uint24 constant twapDuration = 3600;

address constant chainlinkOracleWrapper = 0xa552DfC7c9242A8F63a120901AAec76aC2473398;

contract DeployAeroPrivateVault is CreateXScript {
    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        console.log("Deployer : ");
        console.logAddress(msg.sender);

        // #region create uni V4 oracle.

        address oracle;

        if (oracleDeployment == OracleDeployment.UniV3Oracle) {
            bytes memory initCode = abi.encodePacked(
                creationCodeUniV3Oracle,
                abi.encode(
                    pool,
                    twapDuration
                )
            );

            oracle = CreateX.deployCreate(initCode);

            console.log("V3 Oracle Wrapper : ");
            console.logAddress(oracle);
        }
        if (
            oracleDeployment
                == OracleDeployment.ChainlinkOracleWrapper
        ) {
            bytes memory initCode = abi.encodePacked(
                creationCode_chainlinkOracleWrapper,
                abi.encode(
                    token0Decimals,
                    token1Decimals,
                    priceFeed,
                    sequencerUpTimeFeed,
                    outdated,
                    isPriceFeedInversed
                )
            );

            oracle = CreateX.deployCreate(initCode);

            console.log("Chainlink Oracle Wrapper : ");
            console.logAddress(oracle);
        }
        if (
            oracleDeployment
                == OracleDeployment.DeployedChainlinkOracleWrapper
        ) {
            oracle = chainlinkOracleWrapper;

            console.log("Deployed Chainlink Oracle Wrapper : ");
            console.logAddress(oracle);
        }

        // #endregion create uni V4 oracle.

        // #region create private vault.

        bytes memory moduleCreationPayload = abi.encodeWithSelector(
            IAerodromeStandardModulePrivate.initialize.selector,
            IOracleWrapper(oracle),
            maxSlippage,
            aeroReceiver,
            tickSpacing
        );
        bytes memory initManagementPayload = abi.encode(
            IOracleWrapper(oracle),
            maxDeviation,
            cooldownPeriod,
            executor,
            stratAnnouncer,
            maxSlippage
        );

        address vault = IArrakisMetaVaultFactory(factory)
            .deployPrivateVault(
            salt,
            token0,
            token1,
            vaultOwner,
            upgreadableBeacon,
            moduleCreationPayload,
            initManagementPayload
        );

        console.logString("Aerodrome Private Vault Address : ");
        console.logAddress(vault);

        // #endregion create private vault.

        vm.stopBroadcast();
    }
}