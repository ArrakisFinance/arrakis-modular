// SPDX-License-Identifier: UNLISENSED
pragma solidity 0.8.19;

contract HOTMock {
    uint256 internal _maxToken0VolumeToQuote;
    uint256 internal _maxToken1VolumeToQuote;

    function setTokenVolumes(
        uint256 maxToken0VolumeToQuote,
        uint256 maxToken1VolumeToQuote
    ) external {
        _maxToken0VolumeToQuote = maxToken0VolumeToQuote;
        _maxToken1VolumeToQuote = maxToken1VolumeToQuote;
    }

    function setManager(
        address _manager
    ) external {}
    function setPause(
        bool _value
    ) external {}
    function setMaxTokenVolumes(
        uint256 maxToken0VolumeToQuote,
        uint256 maxToken1VolumeToQuote
    ) external {}

    function maxTokenVolumes()
        external
        view
        returns (uint256, uint256)
    {
        return (_maxToken0VolumeToQuote, _maxToken1VolumeToQuote);
    }
}

contract NotHOT {
    function testCallFailed() external {}
}
