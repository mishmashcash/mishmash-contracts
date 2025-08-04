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

import { SafeMath } from "@openzeppelin/contracts/math/SafeMath.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Initializable } from "@openzeppelin/contracts/proxy/Initializable.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import { MASH } from "../token/MASH.sol";
import { StakingRewards } from "../staking/StakingRewards.sol";
import "../interfaces/IMishMashInstance.sol";
import "../proxy/MishMashRouter.sol";
import "../proxy/FeeManager.sol";

struct RelayerState {
  address relayerAddress;
  string relayerName;
  string hostName;
  uint256 balance;
}

/**
 * @notice Registry contract, one of the main contracts of this protocol upgrade.
 *         The contract should store relayers' addresses and data attributed to the
 *         master address of the relayer. This data includes the relayers stake and
 *         his ensHash.
 *         A relayers master address has a number of subaddresses called "workers",
 *         these are all addresses which burn stake in communication with the proxy.
 *         If a relayer is not registered, he is not displayed on the frontend.
 * @dev CONTRACT RISKS:
 *      - if setter functions are compromised, relayer metadata would be at risk, including the noted amount of his balance
 *      - if burn function is compromised, relayers run the risk of being unable to handle withdrawals
 *      - the above risk also applies to the nullify balance function
 * */
contract RelayerRegistry is Initializable {
  using SafeMath for uint256;
  using SafeERC20 for MASH;

  address public immutable governance;
  MASH public mash;
  StakingRewards public staking;
  FeeManager public feeManager;

  address public proxyRouter;
  uint256 public minStakeAmount;

  mapping(address => RelayerState) public relayers;
  mapping(address => address) public workers;

  event RelayerBalanceNullified(address relayer);
  event WorkerRegistered(address relayer, address worker);
  event WorkerUnregistered(address relayer, address worker);
  event StakeAddedToRelayer(address relayer, uint256 amountStakeAdded);
  event StakeBurned(address relayer, uint256 amountBurned);
  event MinimumStakeAmount(uint256 minStakeAmount);
  event RouterRegistered(address proxyRouter);
  event RelayerRegistered(string hostName, address relayerAddress, uint256 stakedAmount);

  modifier onlyGovernance() {
    require(msg.sender == governance, "only governance");
    _;
  }

  modifier onlyRouter() {
    require(msg.sender == proxyRouter, "only proxy");
    _;
  }

  modifier onlyRelayer(address sender, address relayer) {
    require(workers[sender] == relayer, "only relayer");
    _;
  }

  constructor(address _governance) {
    governance = _governance;
  }

  /**
   * @notice initialize function for upgradeability
   * @dev this contract will be deployed behind a proxy and should not assign values at logic address,
   *      params left out because self explainable
   * */
  function initialize(address _proxyRouter, address _mash, address _staking, address _feeManager, uint256 _minStakeAmount) external initializer {
    proxyRouter = _proxyRouter;
    mash = MASH(_mash);
    staking = StakingRewards(_staking);
    feeManager = FeeManager(_feeManager);
    minStakeAmount = _minStakeAmount;
  }

  /**
   * @notice This function should register a master address and optionally a set of workeres for a relayer + metadata
   * @dev Relayer can't steal other relayers workers since they are registered, and a wallet (msg.sender check) can always unregister itself
   * @param hostName ens name of the relayer
   * @param stake the initial amount of stake in MASH the relayer is depositing
   * */
  function register(
    string calldata relayerName,
    string calldata hostName,
    uint256 stake,
    address[] calldata workersToRegister
  ) external {
    _register(msg.sender, relayerName, hostName, stake, workersToRegister);
  }

  /**
   * @dev Register function equivalent with permit-approval instead of regular approve.
   * */
  function registerPermit(
    string calldata relayerName,
    string calldata hostName,
    uint256 stake,
    address[] calldata workersToRegister,
    address relayer,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) external {
    mash.permit(relayer, address(this), stake, deadline, v, r, s);
    _register(relayer, relayerName, hostName, stake, workersToRegister);
  }

  function _register(
    address relayer,
    string calldata relayerName,
    string calldata hostName,
    uint256 stake,
    address[] calldata workersToRegister
  ) internal {
    require(workers[relayer] == address(0), "cant register again");
    RelayerState storage metadata = relayers[relayer];

    require(metadata.relayerAddress == address(0), "registered already");
    require(stake >= minStakeAmount, "!min_stake");

    if(stake > 0){
      mash.safeTransferFrom(relayer, address(staking), stake);
    }
    emit StakeAddedToRelayer(relayer, stake);

    metadata.relayerAddress = relayer;
    metadata.relayerName = relayerName;
    metadata.hostName = hostName;
    metadata.balance = stake;
    workers[relayer] = relayer;

    for (uint256 i = 0; i < workersToRegister.length; i++) {
      address worker = workersToRegister[i];
      _registerWorker(relayer, worker);
    }

    emit RelayerRegistered(hostName, relayer, stake);
  }

  /**
   * @notice This function should allow relayers to register more workeres
   * @param relayer Relayer which should send message from any worker which is already registered
   * @param worker Address to register
   * */
  function registerWorker(address relayer, address worker) external onlyRelayer(msg.sender, relayer) {
    _registerWorker(relayer, worker);
  }

  function _registerWorker(address relayer, address worker) internal {
    require(workers[worker] == address(0), "can't steal an address");
    workers[worker] = relayer;
    emit WorkerRegistered(relayer, worker);
  }

  /**
   * @notice This function should allow anybody to unregister an address they own
   * @dev designed this way as to allow someone to unregister themselves in case a relayer misbehaves
   *      - this should be followed by an action like burning relayer stake
   *      - there was an option of allowing the sender to burn relayer stake in case of malicious behaviour, this feature was not included in the end
   *      - reverts if trying to unregister master, otherwise contract would break. in general, there should be no reason to unregister master at all
   * */
  function unregisterWorker(address worker) external {
    if (worker != msg.sender) require(workers[worker] == msg.sender, "only owner of worker");
    require(workers[worker] != worker, "cant unregister master");
    emit WorkerUnregistered(workers[worker], worker);
    workers[worker] = address(0);
  }

  /**
   * @notice This function should allow anybody to stake to a relayer more MASH
   * @param relayer Relayer main address to stake to
   * @param stake Stake to be added to relayer
   * */
  function stakeToRelayer(address relayer, uint256 stake) external {
    _stakeToRelayer(msg.sender, relayer, stake);
  }

  /**
   * @dev stakeToRelayer function equivalent with permit-approval instead of regular approve.
   * @param staker address from that stake is paid
   * */
  function stakeToRelayerPermit(
    address relayer,
    uint256 stake,
    address staker,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) external {
    mash.permit(staker, address(this), stake, deadline, v, r, s);
    _stakeToRelayer(staker, relayer, stake);
  }

  function _stakeToRelayer(
    address staker,
    address relayer,
    uint256 stake
  ) internal {
    require(workers[relayer] == relayer, "!registered");
    mash.safeTransferFrom(staker, address(staking), stake);
    relayers[relayer].balance = stake.add(relayers[relayer].balance);
    emit StakeAddedToRelayer(relayer, stake);
  }

  /**
   * @notice This function should burn some relayer stake on withdraw and notify staking of this
   * @dev IMPORTANT FUNCTION:
   *      - This should be only called by the proxy router
   *      - Should revert if relayer does not call proxy from valid worker
   *      - Should not overflow
   *      - Should underflow and revert (SafeMath) on not enough stake (balance)
   * @param sender worker to check sender == relayer
   * @param relayer address of relayer who's stake is being burned
   * @param pool instance to get fee for
   * */
  function burn(
    address sender,
    address relayer,
    IMishMashInstance pool
  ) external onlyRouter {
    address masterAddress = workers[sender];
    if (masterAddress == address(0)) {
      require(workers[relayer] == address(0), "Only custom relayer");
      return;
    }

    require(masterAddress == relayer, "only relayer");
    uint256 toBurn = feeManager.instanceFeeWithUpdate(pool);
    relayers[relayer].balance = relayers[relayer].balance.sub(toBurn);
    staking.addBurnRewards(toBurn);
    emit StakeBurned(relayer, toBurn);
  }

  /**
   * @notice This function should allow governance to set the minimum stake amount
   * @param minAmount new minimum stake amount
   * */
  function setMinStakeAmount(uint256 minAmount) external onlyGovernance {
    minStakeAmount = minAmount;
    emit MinimumStakeAmount(minAmount);
  }

  /**
   * @notice This function should allow governance to set a new proxy router address
   * @param _proxyRouter address of the new proxy
   * */
  function setProxyRouter(address _proxyRouter) external onlyGovernance {
    proxyRouter = _proxyRouter;
    emit RouterRegistered(_proxyRouter);
  }

  /**
   * @notice This function should allow governance to nullify a relayers balance
   * @dev IMPORTANT FUNCTION:
   *      - Should nullify the balance
   *      - Adding nullified balance as rewards was refactored to allow for the flexibility of these funds (for gov to operate with them)
   * @param relayer address of relayer who's balance is to nullify
   * */
  function nullifyBalance(address relayer) external onlyGovernance {
    address masterAddress = workers[relayer];
    require(relayer == masterAddress, "must be master");
    relayers[masterAddress].balance = 0;
    emit RelayerBalanceNullified(relayer);
  }

  /**
   * @notice This function should check if a worker is associated with a relayer
   * @param toResolve address to check
   * @return true if is associated
   * */
  function isRelayer(address toResolve) external view returns (bool) {
    return workers[toResolve] != address(0);
  }

  /**
   * @notice This function should check if a worker is registered to the relayer stated
   * @param relayer relayer to check
   * @param toResolve address to check
   * @return true if registered
   * */
  function isRelayerRegistered(address relayer, address toResolve) external view returns (bool) {
    return workers[toResolve] == relayer;
  }

  /**
   * @notice This function should get a relayers name
   * @param relayer address to fetch for
   * @return relayer's name
   * */
  function getRelayerName(address relayer) external view returns (string memory) {
    return relayers[workers[relayer]].relayerName;
  }

  /**
   * @notice This function should get a relayers host name
   * @param relayer address to fetch for
   * @return relayer's host name
   * */
  function getRelayerHostName(address relayer) external view returns (string memory) {
    return relayers[workers[relayer]].hostName;
  }

  /**
   * @notice This function should get a relayers balance
   * @param relayer relayer who's balance is to fetch
   * @return relayer's balance
   * */
  function getRelayerBalance(address relayer) external view returns (uint256) {
    return relayers[workers[relayer]].balance;
  }

  /**
   * @notice This function allows a relayer to update their name
   * @param relayer relayer who's relayer name to update
   * @param _relayerName the new relayer name
   * */
  function updateRelayerName(address relayer, string memory _relayerName) external onlyRelayer(msg.sender, relayer) {
    relayers[workers[relayer]].relayerName = _relayerName;
  }

  /**
   * @notice This function allows a relayer to update their hostname
   * @param relayer relayer who's hostname to update
   * @param _hostName the new hostname
   * */
  function updateRelayerHostname(address relayer, string memory _hostName) external onlyRelayer(msg.sender, relayer) {
    relayers[workers[relayer]].hostName = _hostName;
  }
}