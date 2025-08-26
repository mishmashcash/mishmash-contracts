// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

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

/**
 * @title ComplianceRegistry
 * @notice The MishMash.cash protocol was deployed in good faith with no intent to facilitate criminal activity.
 *         MishMash advocates and maintains that privacy is essential for freedom, however not at the expense of 
 *         breaking the law. This contract is used to manage the compliance on the MishMash.cash platform. It allows 
 *         DAO goverenance to manage adding and removing curators, which are intended to be parties such as OFAC and/or 
 *         law enforcement. Curators can add and remove accounts from the sanction list with provided justification.
 *         The sanction list is enforced by the Instance contracts
 */
contract ComplianceRegistry {

    address public governance;
    mapping(address => bool) public isCurator;
    mapping(address => bool) public isSanctioned;
    mapping(address => string) public sanctionReason;
    
    constructor(address _governance, address[] memory _initialSanctionedAccounts, string memory _initialSanctionReason) {
        governance = _governance;
        
        for (uint256 i = 0; i < _initialSanctionedAccounts.length; i++) {
            isSanctioned[_initialSanctionedAccounts[i]] = true;
            sanctionReason[_initialSanctionedAccounts[i]] = _initialSanctionReason;
        }
        emit AddedToSanctionList(_initialSanctionedAccounts, _initialSanctionReason);
    }

    modifier onlyGovernance {
        require(msg.sender == governance, "Only governance can call this function");
        _;
    }

    modifier onlyCurators {
        require(isCurator[msg.sender] || msg.sender == governance, "Only curators can call this function");
        _;
    }

    event ComplianceCuratorAdded(address indexed account);
    event ComplianceCuratorRemoved(address indexed account);
    event AddedToSanctionList(address[] indexed accounts, string justification);
    event RemovedFromSanctionList(address[] indexed accounts);

    function addCurator(address account) external onlyGovernance {
        isCurator[account] = true;
        emit ComplianceCuratorAdded(account);
    }

    function removeCurator(address account) external onlyGovernance {
        isCurator[account] = false;
        emit ComplianceCuratorRemoved(account);
    }

    function addToSanctionList(address[] memory accounts, string memory justification) external onlyCurators {
        require(bytes(justification).length > 0, "Reason cannot be empty");
        for (uint256 i = 0; i < accounts.length; i++) {
            address account = accounts[i];
            isSanctioned[account] = true;
            sanctionReason[account] = justification;
        }
        emit AddedToSanctionList(accounts, justification);
    }

    function removeFromSanctionList(address[] memory accounts) external onlyCurators {
        for (uint256 i = 0; i < accounts.length; i++) {
            address account = accounts[i];
            isSanctioned[account] = false;
            sanctionReason[account] = "";
        }
        emit RemovedFromSanctionList(accounts);
    }
}