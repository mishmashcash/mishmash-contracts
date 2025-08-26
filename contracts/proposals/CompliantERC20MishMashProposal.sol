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

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../core/ERC20MishMash.sol";

contract CompliantERC20MishMashProposal {

    uint32 immutable merkleTreeHeight = 20;
    IVerifier immutable verifier;
    IHasher immutable hasher;
    IComplianceRegistry immutable complianceRegistry;
    IERC20 immutable token;
    uint immutable denomination;

    constructor(IVerifier _verifier, IHasher _hasher, IComplianceRegistry _complianceRegistry, IERC20 _token, uint _denomination) {
        verifier = _verifier;
        hasher = _hasher;
        complianceRegistry = _complianceRegistry;
        token = _token;
        denomination = _denomination;
    }
    
    function executeProposal() external {

        ERC20MishMash erc20Instance = new ERC20MishMash(verifier, hasher, complianceRegistry, denomination, merkleTreeHeight, token);

        bytes memory callData = abi.encodeWithSignature(
            "updateInstance((address,(bool,address,uint256,uint8,uint32)))",
            address(erc20Instance),
            true, // isERC20
            address(token), // token
            denomination, // ETN amount
            1, // InstanceState.ENABLED
            0  // protocolFeePercentage
        );

        Governance governance = Governance(address(this));
        governance.executeCall(governance.instanceRegistry(), callData);
    }
}

interface Governance {
    function instanceRegistry() external view returns (address);
    function executeCall(address target, bytes calldata data) external;
}