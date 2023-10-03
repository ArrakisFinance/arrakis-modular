// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {IArrakisMetaVaultV2} from "./interfaces/IArrakisMetaVaultV2.sol";
import {ArrakisMetaVault, IArrakisLPModuleVault, CallFailed} from "./ArrakisMetaVault.sol";
import {EnumerableSet} from "openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";

error SameModule();
error ModuleNotEmpty(uint256 amount0, uint256 amount1);
error AlreadyWhitelisted(address module);
error NotWhitelistedModule(address module);
error ActiveModule();

contract ArrakisMetaVaultV2 is IArrakisMetaVaultV2, ArrakisMetaVault {
    using EnumerableSet for EnumerableSet.AddressSet;

    EnumerableSet.AddressSet internal _whitelistedModules;

    constructor(
        address token0_,
        address token1_,
        address owner_,
        uint256 init0_,
        uint256 init1_,
        address module_
    ) ArrakisMetaVault(token0_, token1_, owner_, init0_, init1_, module_) {}

    function setModule(
        address module_,
        bytes[] calldata payloads_
    ) external onlyManager {
        if (address(module) == module_) revert SameModule();
        if (!_whitelistedModules.contains(module_))
            revert NotWhitelistedModule(module_);

        (uint256 amount0, uint256 amount1) = module.totalUnderlying();
        if (amount0 != 0 || amount1 != 0)
            revert ModuleNotEmpty(amount0, amount1);

        module = IArrakisLPModuleVault(module_);

        uint256 len = payloads_.length;
        for (uint256 i = 0; i < len; i++) {
            (bool success, ) = address(module).call(payloads_[i]);

            if (!success) revert CallFailed();
        }

        emit LogSetModule(module_, payloads_);
    }

    function whitelistModules(address[] calldata modules_) external onlyOwner {
        uint256 len = modules_.length;
        for(uint256 i; i<len; i++) {
            if(_whitelistedModules.contains(modules_[i]))
                revert NotWhitelistedModule(modules_[i]);
            _whitelistedModules.add(modules_[i]);
        }

        emit LogWhiteListedModules(modules_);
    }

    function blacklistModules(address[] calldata modules_) external onlyOwner {
        uint256 len = modules_.length;
        for(uint256 i; i<len; i++) {
            if(!_whitelistedModules.contains(modules_[i]))
                revert AlreadyWhitelisted(modules_[i]);
            if(address(module) == modules_[i])
                revert ActiveModule();
            _whitelistedModules.remove(modules_[i]);
        }

        emit LogBlackListedModules(modules_);
    }

    function whitelistedModules() external view returns(address[] memory modules) {
        return _whitelistedModules.values();
    }
}
