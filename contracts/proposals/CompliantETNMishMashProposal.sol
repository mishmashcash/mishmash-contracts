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
    InstanceRegistry immutable instanceRegistry;

    constructor(IVerifier _verifier, IHasher _hasher, IComplianceRegistry _complianceRegistry, InstanceRegistry _instanceRegistry) {
        verifier = _verifier;
        hasher = _hasher;
        complianceRegistry = _complianceRegistry;
        instanceRegistry = _instanceRegistry;
    }
    
    function executeProposal() external {
        
        instanceRegistry.removeInstance(3);
        instanceRegistry.removeInstance(2);
        instanceRegistry.removeInstance(1);
        instanceRegistry.removeInstance(0);
        
        ETNMishMash etnInstance1 = new ETNMishMash(verifier, hasher, complianceRegistry, 1000 ether, merkleTreeHeight);
        instanceRegistry.updateInstance(
            InstanceRegistry.MishMashInstance({
                addr: address(etnInstance1),
                instance: InstanceRegistry.Instance({
                    isERC20: false,
                    token: address(0),
                    denomination: 1000 ether,
                    state: InstanceRegistry.InstanceState.ENABLED,
                    poolSwappingFee: 0,
                    protocolFeePercentage: 0
                })
            })
        );


        ETNMishMash etnInstance2 = new ETNMishMash(verifier, hasher, complianceRegistry, 10000 ether, merkleTreeHeight);
        instanceRegistry.updateInstance(
            InstanceRegistry.MishMashInstance({
                addr: address(etnInstance2),
                instance: InstanceRegistry.Instance({
                    isERC20: false,
                    token: address(0),
                    denomination: 10000 ether,
                    state: InstanceRegistry.InstanceState.ENABLED,
                    poolSwappingFee: 0,
                    protocolFeePercentage: 0
                })
            })
        );

        ETNMishMash etnInstance3 = new ETNMishMash(verifier, hasher, complianceRegistry, 100000 ether, merkleTreeHeight);
        instanceRegistry.updateInstance(
            InstanceRegistry.MishMashInstance({
                addr: address(etnInstance3),
                instance: InstanceRegistry.Instance({
                    isERC20: false,
                    token: address(0),
                    denomination: 100000 ether,
                    state: InstanceRegistry.InstanceState.ENABLED,
                    poolSwappingFee: 0,
                    protocolFeePercentage: 0
                })
            })
        );

        ETNMishMash etnInstance4 = new ETNMishMash(verifier, hasher, complianceRegistry, 1000000 ether, merkleTreeHeight);
        instanceRegistry.updateInstance(
            InstanceRegistry.MishMashInstance({
                addr: address(etnInstance4),
                instance: InstanceRegistry.Instance({
                    isERC20: false,
                    token: address(0),
                    denomination: 1000000 ether,
                    state: InstanceRegistry.InstanceState.ENABLED,
                    poolSwappingFee: 0,
                    protocolFeePercentage: 0
                })
            })
        );

        
    }
}

interface InstanceRegistry {

    enum InstanceState {
        DISABLED,
        ENABLED
    }

    struct Instance {
        bool isERC20;
        address token;
        uint256 denomination;
        InstanceState state;
        uint24 poolSwappingFee; 
        uint32 protocolFeePercentage;
    }

    struct MishMashInstance {
        address addr;
        Instance instance;
    }

    function updateInstance(MishMashInstance calldata _instance) external;
    function removeInstance(uint256 _instanceId) external;
}