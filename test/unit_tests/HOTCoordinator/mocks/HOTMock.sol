// SPDX-License-Identifier: UNLISENSED
pragma solidity 0.8.19;

contract HOTMock {
    function setManager(address _manager) external {}
    function setPause(bool _value) external {}
    function setMaxTokenVolumes(uint256 maxToken0VolumeToQuote, uint256 maxToken1VolumeToQuote) external {}
}

contract NotHOT {
    function testCallFailed() external {}
}