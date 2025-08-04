// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

interface IGasCompensationVault {
    function compensateGas(address recipient, uint256 gasAmount) external;
    function withdrawToGovernance(uint256 amount) external;
}