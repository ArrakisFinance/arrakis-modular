// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

contract PalmNFTMock {
    address internal _owner;
    address internal _approveTo;

    function setOwner(address owner_) external {
        _owner = owner_;
    }

    function setApprovedTo(address approvedTo_) external {
        _approveTo = approvedTo_;
    }

    function safeTransferFrom(
        address,
        address to_,
        uint256
    ) external {
        _owner = to_;
    }

    function ownerOf(uint256) external view returns (address) {
        return _owner;
    }

    function getApproved(uint256) external view returns (address) {
        return _approveTo;
    }

    function failingCall() external pure {
        revert();
    }
}
