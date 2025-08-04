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

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/proxy/Initializable.sol";
import "../interfaces/IUserVault.sol";
import "../interfaces/IGasCompensationVault.sol";
import "../interfaces/IStakingRewards.sol";
import "../token/MASH.sol";
import "./Configuration.sol";
import "./Delegation.sol";


contract MishMashGovernance is Initializable, Configuration, Delegation {
    
    using SafeMath for uint256;

    // ============ ENUMS & STRUCTS============
    
    enum ProposalState {
        Pending,
        Active,
        Defeated,
        Timelocked,
        AwaitingExecution,
        Executed,
        Expired
    }
    
    struct Proposal {
        address proposer;
        address target;
        uint256 startTime;
        uint256 endTime;
        uint256 forVotes;
        uint256 againstVotes;
        bool executed;
        bool extended;
        mapping(address => Receipt) receipts;
    }

    struct Receipt {
        bool hasVoted;
        bool support;
        uint256 votes;
    }

    // ============ STATE VARIABLES ============
    
    // Core contract instances
    MASH public mash;
    IUserVault public userVault;
    IGasCompensationVault public gasCompensationVault;
    IStakingRewards public stakingRewards;
    
    // Proposal management
    Proposal[] public proposals;
    mapping(uint256 => bytes32) public proposalCodehashes;
    
    // User state mappings
    mapping(address => uint256) public latestProposalIds;
    mapping(address => uint256) public canWithdrawAfter;

    // ============ INITIALIZATION ============
    
    function initialize(address _mash, address _userVault, address _gasCompensationVault, address _stakingRewards) public initializer {
        mash = MASH(_mash);
        userVault = IUserVault(_userVault);
        gasCompensationVault = IGasCompensationVault(_gasCompensationVault);
        stakingRewards = IStakingRewards(_stakingRewards);
        
        proposals.push();
        Proposal storage initialProposal = proposals[0];
        initialProposal.proposer = address(this);
        initialProposal.target = 0x000000000000000000000000000000000000dEaD;
        initialProposal.startTime = 0;
        initialProposal.endTime = 0;
        initialProposal.forVotes = 0;
        initialProposal.againstVotes = 0;
        initialProposal.executed = true;
        initialProposal.extended = false;

        _initializeConfiguration();
    }

    // ============ EXTERNAL FUNCTIONS - TOKEN MANAGEMENT ============
    
    function lock(address owner, uint256 amount, uint256 deadline, uint8 v, bytes32 r, bytes32 s) public virtual updateRewards(owner) {
        mash.permit(owner, address(this), amount, deadline, v, r, s);
        _transferTokens(owner, amount);
    }

    function lockWithApproval(uint256 amount) public virtual updateRewards(msg.sender) {
        _transferTokens(msg.sender, amount);
    }

    function unlock(uint256 amount) public virtual updateRewards(msg.sender) {
        require(getBlockTimestamp() > canWithdrawAfter[msg.sender], "Governance: tokens are locked");
        lockedBalance[msg.sender] = lockedBalance[msg.sender].sub(amount, "Governance: insufficient balance");
        userVault.withdrawMash(msg.sender, amount);
    }

    // ============ EXTERNAL FUNCTIONS - PROPOSAL MANAGEMENT ============
    
    function propose(address target, string memory description) external returns (uint256) {
        return _propose(msg.sender, target, description);
    }

    function execute(uint256 proposalId) public payable virtual {
        require(state(proposalId) == ProposalState.AwaitingExecution, "Governance::execute: invalid proposal state");
        Proposal storage proposal = proposals[proposalId];
        require(msg.sender != address(this), "Governance::propose: pseudo-external function");
        address target = proposal.target;
        bytes32 proposalCodehash;
        assembly {
            proposalCodehash := extcodehash(target)
        }
        require(
            proposalCodehash == proposalCodehashes[proposalId],
            "Governance::propose: metamorphic contracts not allowed"
        );
        proposal.executed = true;
        require(Address.isContract(target), "Governance::execute: not a contract");
        (bool success, bytes memory data) = target.delegatecall(abi.encodeWithSignature("executeProposal()"));
        if (!success) {
            if (data.length > 0) {
                revert(string(data));
            } else {
                revert("Proposal execution failed");
            }
        }
        emit ProposalExecuted(proposalId);
    }

    // ============ EXTERNAL FUNCTIONS - VOTING ============
    
    function castVote(uint256 proposalId, bool support)
        external
        virtual
        gasCompensation(
            msg.sender,
            !hasAccountVoted(proposalId, msg.sender) && !checkIfQuorumReached(proposalId),
            (msg.sender == tx.origin ? 21e3 : 0)
        )
    {
        _castVote(msg.sender, proposalId, support);
    }

    function castDelegatedVote(address[] memory from, uint256 proposalId, bool support)
        external
        virtual
        override(Delegation)
    {
        require(from.length > 0, "Can not be empty");
        _castDelegatedVote(
            from,
            proposalId,
            support,
            !hasAccountVoted(proposalId, msg.sender) && !checkIfQuorumReached(proposalId)
        );
    }

    // ============ EXTERNAL FUNCTIONS - VIEW FUNCTIONS ============
    
    function state(uint256 proposalId) public view virtual returns (ProposalState) {
        require(proposalId <= proposalCount() && proposalId > 0, "Governance::state: invalid proposal id");
        Proposal storage proposal = proposals[proposalId];
        if (getBlockTimestamp() <= proposal.startTime) {
            return ProposalState.Pending;
        } else if (getBlockTimestamp() <= proposal.endTime) {
            return ProposalState.Active;
        } else if (proposal.executed) {
            return ProposalState.Executed;
        } else if (
            proposal.forVotes <= proposal.againstVotes || proposal.forVotes + proposal.againstVotes < QUORUM_VOTES
        ) {
            return ProposalState.Defeated;
        } else if (getBlockTimestamp() >= proposal.endTime.add(EXECUTION_DELAY).add(EXECUTION_EXPIRATION)) {
            return ProposalState.Expired;
        } else if (getBlockTimestamp() >= proposal.endTime.add(EXECUTION_DELAY)) {
            return ProposalState.AwaitingExecution;
        } else {
            return ProposalState.Timelocked;
        }
    }

    function getReceipt(uint256 proposalId, address voter) public view returns (Receipt memory) {
        return proposals[proposalId].receipts[voter];
    }

    function proposalCount() public view returns (uint256) {
        return proposals.length - 1;
    }

    function checkIfQuorumReached(uint256 proposalId) public view returns (bool) {
        return (proposals[proposalId].forVotes + proposals[proposalId].againstVotes >= QUORUM_VOTES);
    }

    function hasAccountVoted(uint256 proposalId, address account) public view returns (bool) {
        return proposals[proposalId].receipts[account].hasVoted;
    }

    function returnAdminAddress() public pure virtual returns (address) {
        return 0x6b6FF3F8562A32c3E8beF58908054285B635F0cb;
    }

    function version() external pure virtual returns (string memory) {
        return "v5.consolidated";
    }

    // ============ EXTERNAL FUNCTIONS - ADMIN ============
    
    function setGasCompensations(uint256 gasCompensationsLimit) external virtual onlyAdmin {
        require(
            payable(address(gasCompensationVault)).send(
                Math.min(gasCompensationsLimit, address(this).balance)
            )
        );
    }

    function withdrawFromHelper(uint256 amount) external virtual onlyAdmin {
        gasCompensationVault.withdrawToGovernance(amount);
    }

    // ============ INTERNAL FUNCTIONS - PROPOSAL MANAGEMENT ============
    
    function _propose(
        address proposer,
        address target,
        string memory description
    ) internal virtual override(Delegation) returns (uint256 proposalId) {
        uint256 votingPower = lockedBalance[proposer];
        require(votingPower >= PROPOSAL_THRESHOLD, "Governance::propose: proposer votes below proposal threshold");
        require(Address.isContract(target), "Governance::propose: not a contract");
        uint256 latestProposalId = latestProposalIds[proposer];
        if (latestProposalId != 0) {
            ProposalState proposersLatestProposalState = state(latestProposalId);
            require(
                proposersLatestProposalState != ProposalState.Active &&
                    proposersLatestProposalState != ProposalState.Pending,
                "Governance::propose: one live proposal per proposer, found an already active proposal"
            );
        }
        uint256 startTime = getBlockTimestamp().add(VOTING_DELAY);
        uint256 endTime = startTime.add(VOTING_PERIOD);
        
        proposals.push();
        Proposal storage newProposal = proposals[proposals.length - 1];
        newProposal.proposer = proposer;
        newProposal.target = target;
        newProposal.startTime = startTime;
        newProposal.endTime = endTime;
        newProposal.forVotes = 0;
        newProposal.againstVotes = 0;
        newProposal.executed = false;
        newProposal.extended = false;
        
        proposalId = proposalCount();
        latestProposalIds[newProposal.proposer] = proposalId;
        _lockTokens(proposer, endTime.add(VOTE_EXTEND_TIME).add(EXECUTION_EXPIRATION).add(EXECUTION_DELAY));
        emit ProposalCreated(proposalId, proposer, target, startTime, endTime, description);
        bytes32 proposalCodehash;
        assembly {
            proposalCodehash := extcodehash(target)
        }
        proposalCodehashes[proposalId] = proposalCodehash;
        return proposalId;
    }

    // ============ INTERNAL FUNCTIONS - VOTING ============
    
    function _castDelegatedVote(address[] memory from, uint256 proposalId, bool support, bool gasCompensated)
        internal
        gasCompensation(msg.sender, gasCompensated, (msg.sender == tx.origin ? 21e3 : 0))
    {
        for (uint256 i = 0; i < from.length; i++) {
            address delegator = from[i];
            require(
                delegatedTo[delegator] == msg.sender || delegator == msg.sender, "Governance: not authorized"
            );
            require(!gasCompensated || !hasAccountVoted(proposalId, delegator), "Governance: voted already");
            _castVote(delegator, proposalId, support);
        }
    }

    function _castVote(address voter, uint256 proposalId, bool support) internal override(Delegation) {
        require(state(proposalId) == ProposalState.Active, "Governance::_castVote: voting is closed");
        Proposal storage proposal = proposals[proposalId];
        Receipt storage receipt = proposal.receipts[voter];
        bool beforeVotingState = proposal.forVotes <= proposal.againstVotes;
        uint256 votes = lockedBalance[voter];
        require(votes > 0, "Governance: balance is 0");
        if (receipt.hasVoted) {
            if (receipt.support) {
                proposal.forVotes = proposal.forVotes.sub(receipt.votes);
            } else {
                proposal.againstVotes = proposal.againstVotes.sub(receipt.votes);
            }
        }
        if (support) {
            proposal.forVotes = proposal.forVotes.add(votes);
        } else {
            proposal.againstVotes = proposal.againstVotes.add(votes);
        }
        if (!proposal.extended && proposal.endTime.sub(getBlockTimestamp()) < CLOSING_PERIOD) {
            bool afterVotingState = proposal.forVotes <= proposal.againstVotes;
            if (beforeVotingState != afterVotingState) {
                proposal.extended = true;
                proposal.endTime = proposal.endTime.add(VOTE_EXTEND_TIME);
            }
        }
        receipt.hasVoted = true;
        receipt.support = support;
        receipt.votes = votes;
        _lockTokens(voter, proposal.endTime.add(VOTE_EXTEND_TIME).add(EXECUTION_EXPIRATION).add(EXECUTION_DELAY));
        emit Voted(proposalId, voter, support, votes);
    }

    // ============ INTERNAL FUNCTIONS - UTILITY ============
    
    function _transferTokens(address owner, uint256 amount) internal virtual {
        require(mash.transferFrom(owner, address(userVault), amount), "MASH: transferFrom failed");
        lockedBalance[owner] = lockedBalance[owner].add(amount);
    }

    function _lockTokens(address owner, uint256 timestamp) internal {
        if (timestamp > canWithdrawAfter[owner]) {
            canWithdrawAfter[owner] = timestamp;
        }
    }

    function getBlockTimestamp() internal view virtual returns (uint256) {
        return block.timestamp;
    }

    // ============ MODIFIERS ============
    
    modifier onlyAdmin() {
        require(msg.sender == returnAdminAddress(), "only admin");
        _;
    }

    modifier gasCompensation(address account, bool eligible, uint256 extra) {
        if (eligible) {
            uint256 startGas = gasleft();
            _;
            uint256 gasToCompensate = startGas.sub(gasleft()).add(extra).add(10e3);
            gasCompensationVault.compensateGas(account, gasToCompensate);
        } else {
            _;
        }
    }

    modifier updateRewards(address account) {
        try stakingRewards.updateRewardsOnLockedBalanceChange(account, lockedBalance[account]) {
            emit RewardUpdateSuccessful(account);
        } catch (bytes memory errorData) {
            emit RewardUpdateFailed(account, errorData);
        }
        _;
    }

    // ============ EVENTS ============
    
    event ProposalCreated(
        uint256 indexed id,
        address indexed proposer,
        address target,
        uint256 startTime,
        uint256 endTime,
        string description
    );
    event Voted(uint256 indexed proposalId, address indexed voter, bool indexed support, uint256 votes);
    event ProposalExecuted(uint256 indexed proposalId);
    event RewardUpdateSuccessful(address indexed account);
    event RewardUpdateFailed(address indexed account, bytes indexed errorData);

    // ============ FALLBACK ============
    
    receive() external payable { }
} 