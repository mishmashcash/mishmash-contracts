// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

/*
 * 888b     d888 d8b          888      888b     d888                   888                                     888     
 * 8888b   d8888 Y8P          888      8888b   d8888                   888                                     888     
 * 88888b.d88888              888      88888b.d88888                   888                                     888     
 * 888Y88888P888 888 .d8888b  88888b.  888Y88888P888  8888b.  .d8888b  88888b.       .d8888b  8888b.  .d8888b  88888b. 
 * 888 Y888P 888 888 88K      888 "88b 888 Y888P 888     "88b 88K      888 "88b     d88P"        "88b 88K      888 "88b
 * 888  Y8P  888 888 "Y8888b. 888  888 888  Y8P  888 .d888888 "Y8888b. 888  888     888      .d888888 "Y8888b. 888  888
 * 888   "   888 888      X88 888  888 888   "   888 888  888      X88 888  888 d8b Y88b.    888  888      X88 888  888
 * 888       888 888  88888P' 888  888 888       888 "Y888888  88888P' 888  888 Y8P  "Y8888P "Y888888  88888P' 888  888
 *
 * https://ipfs.mishmash.cash
 * https://x.com/MishMash_Cash
 * 
 * MishMash.cash is a Tornado.cash clone enabling non-custodial anonymous transactions on Electroneum 2.0
 */

import "../core/ETNMishMash.sol";

contract CompliantETNMishMashProposal {

    uint32 immutable merkleTreeHeight = 20;
    IVerifier immutable verifier;
    IHasher immutable hasher;
    IComplianceRegistry immutable complianceRegistry;

    constructor(IVerifier _verifier, IHasher _hasher, IComplianceRegistry _complianceRegistry) {
        verifier = _verifier;
        hasher = _hasher;
        complianceRegistry = _complianceRegistry;
    }
    
    function executeProposal() external {
        Governance governance = Governance(address(this));
        
        ETNMishMash etnInstance1 = new ETNMishMash(verifier, hasher, complianceRegistry, 1 ether / 10, merkleTreeHeight);
        bytes memory callData1 = abi.encodeWithSignature(
            "updateInstance((address,(bool,address,uint256,uint8,uint32)))",
            address(etnInstance1),
            false, // isERC20
            address(0), // token
            1 ether / 10, // ETN amount
            1, // InstanceState.ENABLED
            0  // protocolFeePercentage
        );
        governance.executeCall(governance.instanceRegistry(), callData1);

        ETNMishMash etnInstance2 = new ETNMishMash(verifier, hasher, complianceRegistry, 1 ether, merkleTreeHeight);
        bytes memory callData2 = abi.encodeWithSignature(
            "updateInstance((address,(bool,address,uint256,uint8,uint32)))",
            address(etnInstance2),
            false, // isERC20
            address(0), // token
            1 ether, // ETN amount
            1, // InstanceState.ENABLED
            0  // protocolFeePercentage
        );
        governance.executeCall(governance.instanceRegistry(), callData2);

        ETNMishMash etnInstance3 = new ETNMishMash(verifier, hasher, complianceRegistry, 10 ether, merkleTreeHeight);
        bytes memory callData3 = abi.encodeWithSignature(
            "updateInstance((address,(bool,address,uint256,uint8,uint32)))",
            address(etnInstance3),
            false, // isERC20
            address(0), // token
            10 ether, // ETN amount
            1, // InstanceState.ENABLED
            0  // protocolFeePercentage
        );
        governance.executeCall(governance.instanceRegistry(), callData3);

        ETNMishMash etnInstance4 = new ETNMishMash(verifier, hasher, complianceRegistry, 100 ether, merkleTreeHeight);
        bytes memory callData4 = abi.encodeWithSignature(
            "updateInstance((address,(bool,address,uint256,uint8,uint32)))",
            address(etnInstance4),
            false, // isERC20
            address(0), // token
            100 ether, // ETN amount
            1, // InstanceState.ENABLED
            0  // protocolFeePercentage
        );
        governance.executeCall(governance.instanceRegistry(), callData4);
    }
}

interface Governance {
    function instanceRegistry() external view returns (address);
    function executeCall(address target, bytes calldata data) external;
}