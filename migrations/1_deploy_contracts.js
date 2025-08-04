/* eslint-disable indent */
/* global artifacts, web3 */
const fs = require('fs')
const path = require('path')

const GovernanceProxy = artifacts.require('LoopbackProxy')
const MishMashGovernance = artifacts.require('MishMashGovernance')
const MASH = artifacts.require('MASH')
const UserVault = artifacts.require('UserVault')
const Hasher = artifacts.require('Hasher')
const Verifier = artifacts.require('Verifier')
const InstanceRegistry = artifacts.require('InstanceRegistry')
const RelayerRegistry = artifacts.require('RelayerRegistry')
const StakingRewards = artifacts.require('StakingRewards')
const FeeManager = artifacts.require('FeeManager')
const MishMashRouter = artifacts.require('MishMashRouter')
const Echoer = artifacts.require('Echoer')
const Aggregator = artifacts.require('Aggregator')
const ETNMishMash = artifacts.require('ETNMishMash')
const GovernanceUpgradeableProxy = artifacts.require('GovernanceUpgradeableProxy')

module.exports = function (deployer) {
  return deployer.then(async () => {
    // Get the deployer address from web3
    const accounts = await web3.eth.getAccounts()
    const deployerWallet = accounts[0]
    const relayerWallet = process.env.RELAYER_WALLET

    // Helper function to get contract deployment info
    const getContractInfo = async (contract) => {
      const receipt = contract.transactionHash
        ? await web3.eth.getTransactionReceipt(contract.transactionHash)
        : null
      return {
        address: contract.address,
        blockNumber: receipt ? receipt.blockNumber : null,
        transactionHash: contract.transactionHash || null,
      }
    }

    const chainId = await web3.eth.getChainId()

    const ETN_INSTANCE1_DENOMINATION = chainId === 52014 ? 1000000000000000000000000n : 100000000000000000000n
    const ETN_INSTANCE2_DENOMINATION = chainId === 52014 ? 100000000000000000000000n : 10000000000000000000n
    const ETN_INSTANCE3_DENOMINATION = chainId === 52014 ? 10000000000000000000000n : 1000000000000000000n
    const ETN_INSTANCE4_DENOMINATION = chainId === 52014 ? 1000000000000000000000n : 100000000000000000n

    // Initialize deployment tracking object
    const deploymentAddresses = {
      timestamp: new Date().getTime(),
      network: chainId.toString(),
      contracts: {},
    }

    const hasher = await Hasher.deployed()
    const verifier = await Verifier.deployed()

    const governance = await deployer.deploy(MishMashGovernance)
    deploymentAddresses.contracts.MishMashGovernance = await getContractInfo(governance)

    const governanceProxy = await deployer.deploy(GovernanceProxy, governance.address, '0x')
    deploymentAddresses.contracts.GovernanceProxy = await getContractInfo(governanceProxy)

    const mash = await deployer.deploy(MASH, governanceProxy.address, 0, [
      {
        to: governanceProxy.address,
        amount: 700000000000000000000000n, // 700000 MASH
      },
      {
        to: deployerWallet,
        amount: 290000000000000000000000n, // 290000 MASH
      },
      {
        to: relayerWallet,
        amount: 10000000000000000000000n, // 10000 MASH
      },
    ])
    deploymentAddresses.contracts.MASH = await getContractInfo(mash)

    const userVault = await deployer.deploy(UserVault, mash.address, governanceProxy.address)
    deploymentAddresses.contracts.UserVault = await getContractInfo(userVault)

    // GAS COMPENSATION VAULT
    console.log('Deploying GasCompensationVault...')
    var gasCompensationVaultContract = new web3.eth.Contract([
      {
        inputs: [{ internalType: 'address', name: '_governance', type: 'address' }],
        stateMutability: 'nonpayable',
        type: 'constructor',
      },
      {
        inputs: [
          { internalType: 'address', name: 'recipient', type: 'address' },
          { internalType: 'uint256', name: 'gasAmount', type: 'uint256' },
        ],
        name: 'compensateGas',
        outputs: [],
        stateMutability: 'nonpayable',
        type: 'function',
      },
      {
        inputs: [],
        name: 'governance',
        outputs: [{ internalType: 'address', name: '', type: 'address' }],
        stateMutability: 'view',
        type: 'function',
      },
      {
        inputs: [{ internalType: 'uint256', name: 'amount', type: 'uint256' }],
        name: 'withdrawToGovernance',
        outputs: [],
        stateMutability: 'nonpayable',
        type: 'function',
      },
      { stateMutability: 'payable', type: 'receive' },
    ])

    var gasCompensationVault = await gasCompensationVaultContract
      .deploy({
        data:
          '0x6080604052348015600f57600080fd5b5060405161039f38038061039f833981016040819052602c916050565b600080546001600160a01b0319166001600160a01b0392909216919091179055607e565b600060208284031215606157600080fd5b81516001600160a01b0381168114607757600080fd5b9392505050565b6103128061008d6000396000f3fe6080604052600436106100385760003560e01c80635aa6e67514610044578063a99ce80714610080578063e822f784146100a257600080fd5b3661003f57005b600080fd5b34801561005057600080fd5b50600054610064906001600160a01b031681565b6040516001600160a01b03909116815260200160405180910390f35b34801561008c57600080fd5b506100a061009b366004610260565b6100c2565b005b3480156100ae57600080fd5b506100a06100bd366004610298565b610163565b6000546001600160a01b0316331461010c5760405162461bcd60e51b815260206004820152600860248201526737b7363c9033b7bb60c11b60448201526064015b60405180910390fd5b47600061011948846102b1565b9050816000036101295750505050565b836001600160a01b03166108fc8383116101435782610145565b835b6040518115909202916000818181858888f1505050505050505b5050565b6000546001600160a01b031633146101a85760405162461bcd60e51b815260206004820152600860248201526737b7363c9033b7bb60c11b6044820152606401610103565b476101cd8183116101b957826101bb565b815b6000546001600160a01b031690610204565b61015f5760405162461bcd60e51b81526020600482015260086024820152671c185e4819985a5b60c21b6044820152606401610103565b6000826001600160a01b03168260405160006040518083038185875af1925050503d8060008114610251576040519150601f19603f3d011682016040523d82523d6000602084013e610256565b606091505b5090949350505050565b6000806040838503121561027357600080fd5b82356001600160a01b038116811461028a57600080fd5b946020939093013593505050565b6000602082840312156102aa57600080fd5b5035919050565b80820281158282048414176102d657634e487b7160e01b600052601160045260246000fd5b9291505056fea2646970667358221220fe0089c9fe91fdcddcaffad1ff5ec46e03054831b4ef00c958de404818ccdb1464736f6c634300081e0033',
        arguments: [governanceProxy.address],
      })
      .send(
        {
          from: deployerWallet,
          gas: '4700000',
        },
        function (e, contract) {
          if (typeof contract.address !== 'undefined') {
            console.log(
              'Contract mined! address: ' +
                contract.address +
                ' transactionHash: ' +
                contract.transactionHash,
            )
          }
        },
      )

    console.log('GasCompensationVault deployed at:', gasCompensationVault._address)
    deploymentAddresses.contracts.GasCompensationVault = {
      address: gasCompensationVault._address,
      blockNumber: gasCompensationVault.transactionHash
        ? await web3.eth
            .getTransactionReceipt(gasCompensationVault.transactionHash)
            .then((receipt) => receipt.blockNumber)
        : null,
      transactionHash: gasCompensationVault.transactionHash || null,
    }

    // INSTANCE REGISTRY
    const instanceRegistry = await deployer.deploy(InstanceRegistry, governanceProxy.address)
    deploymentAddresses.contracts.InstanceRegistry = await getContractInfo(instanceRegistry)

    const instanceRegistryProxy = await deployer.deploy(
      GovernanceUpgradeableProxy,
      instanceRegistry.address,
      governanceProxy.address,
      '0x',
    )
    deploymentAddresses.contracts.InstanceRegistryProxy = await getContractInfo(instanceRegistryProxy)
    const instanceRegistryProxyWithRealABI = await InstanceRegistry.at(instanceRegistryProxy.address)

    // RELAYER REGISTRY
    const relayerRegistry = await deployer.deploy(RelayerRegistry, governanceProxy.address)
    deploymentAddresses.contracts.RelayerRegistry = await getContractInfo(relayerRegistry)

    const relayerRegistryProxy = await deployer.deploy(
      GovernanceUpgradeableProxy,
      relayerRegistry.address,
      governanceProxy.address,
      '0x',
    )
    deploymentAddresses.contracts.RelayerRegistryProxy = await getContractInfo(relayerRegistryProxy)
    const relayerRegistryProxyWithRealABI = await RelayerRegistry.at(relayerRegistryProxy.address)
    console.log('RelayerRegistryProxy Deployed at:', relayerRegistryProxy.address)

    // STAKING REWARDS
    const stakingRewards = await deployer.deploy(
      StakingRewards,
      governanceProxy.address,
      mash.address,
      relayerRegistryProxy.address,
    )
    deploymentAddresses.contracts.StakingRewards = await getContractInfo(stakingRewards)

    const stakingRewardsProxy = await deployer.deploy(
      GovernanceUpgradeableProxy,
      stakingRewards.address,
      governanceProxy.address,
      '0x',
    )
    deploymentAddresses.contracts.StakingRewardsProxy = await getContractInfo(stakingRewardsProxy)

    // FEE MANAGER
    const feeManager = await deployer.deploy(
      FeeManager,
      mash.address,
      governanceProxy.address,
      instanceRegistryProxy.address,
    )
    deploymentAddresses.contracts.FeeManager = await getContractInfo(feeManager)

    const feeManagerProxy = await deployer.deploy(
      GovernanceUpgradeableProxy,
      feeManager.address,
      governanceProxy.address,
      '0x',
    )
    deploymentAddresses.contracts.FeeManagerProxy = await getContractInfo(feeManagerProxy)

    // ROUTER PROXY
    const mishMashRouter = await deployer.deploy(
      MishMashRouter,
      governanceProxy.address,
      instanceRegistryProxy.address,
      relayerRegistryProxy.address,
    )
    deploymentAddresses.contracts.MishMashRouter = await getContractInfo(mishMashRouter)

    // ECHOER
    const echoer = await deployer.deploy(Echoer)
    deploymentAddresses.contracts.Echoer = await getContractInfo(echoer)

    // AGGREGATOR
    const aggregator = await deployer.deploy(Aggregator, relayerRegistryProxy.address)
    deploymentAddresses.contracts.Aggregator = await getContractInfo(aggregator)

    const etnInstance1 = await deployer.deploy(
      ETNMishMash,
      verifier.address,
      hasher.address,
      ETN_INSTANCE1_DENOMINATION,
      20,
    )
    deploymentAddresses.contracts.EtnInstance1 = await getContractInfo(etnInstance1)

    const etnInstance2 = await deployer.deploy(
      ETNMishMash,
      verifier.address,
      hasher.address,
      ETN_INSTANCE2_DENOMINATION,
      20,
    )
    deploymentAddresses.contracts.EtnInstance2 = await getContractInfo(etnInstance2)

    const etnInstance3 = await deployer.deploy(
      ETNMishMash,
      verifier.address,
      hasher.address,
      ETN_INSTANCE3_DENOMINATION,
      20,
    )
    deploymentAddresses.contracts.EtnInstance3 = await getContractInfo(etnInstance3)

    const etnInstance4 = await deployer.deploy(
      ETNMishMash,
      verifier.address,
      hasher.address,
      ETN_INSTANCE4_DENOMINATION,
      20,
    )
    deploymentAddresses.contracts.EtnInstance4 = await getContractInfo(etnInstance4)

    console.log('Initializing InstanceRegistry...')
    await instanceRegistryProxyWithRealABI.initialize(
      [
        {
          addr: etnInstance1.address,
          instance: {
            isERC20: false,
            token: '0x0000000000000000000000000000000000000000',
            denomination: ETN_INSTANCE1_DENOMINATION,
            state: 1,
            poolSwappingFee: 0,
            protocolFeePercentage: 0,
          },
        },
        {
          addr: etnInstance2.address,
          instance: {
            isERC20: false,
            token: '0x0000000000000000000000000000000000000000',
            denomination: ETN_INSTANCE2_DENOMINATION,
            state: 1,
            poolSwappingFee: 0,
            protocolFeePercentage: 0,
          },
        },
        {
          addr: etnInstance3.address,
          instance: {
            isERC20: false,
            token: '0x0000000000000000000000000000000000000000',
            denomination: ETN_INSTANCE3_DENOMINATION,
            state: 1,
            poolSwappingFee: 0,
            protocolFeePercentage: 0,
          },
        },
        {
          addr: etnInstance4.address,
          instance: {
            isERC20: false,
            token: '0x0000000000000000000000000000000000000000',
            denomination: ETN_INSTANCE4_DENOMINATION,
            state: 1,
            poolSwappingFee: 0,
            protocolFeePercentage: 0,
          },
        },
      ],
      mishMashRouter.address,
    )

    console.log('Initializing RelayerRegistry...')
    await relayerRegistryProxyWithRealABI.initialize(
      mishMashRouter.address,
      mash.address,
      stakingRewardsProxy.address,
      feeManagerProxy.address,
      5000000000000000000000n, // 5000 MASH to be a relayer
    )

    console.log('Initializing MishMashGovernance...')
    const governanceWithRealABI = await MishMashGovernance.at(governanceProxy.address)
    await governanceWithRealABI.initialize(
      mash.address,
      userVault.address,
      gasCompensationVault._address,
      stakingRewardsProxy.address,
    )

    // Save deployment addresses to timestamped JSON file
    const deploymentsDir = path.join(__dirname, '..', 'deployments')
    if (!fs.existsSync(deploymentsDir)) {
      fs.mkdirSync(deploymentsDir, { recursive: true })
    }

    const timestamp = new Date().toISOString().replace(/[:.]/g, '-')
    const deploymentFile = path.join(deploymentsDir, `deployment_${timestamp}.json`)

    fs.writeFileSync(deploymentFile, JSON.stringify(deploymentAddresses, null, 2))
    console.log(`Deployment addresses saved to: ${deploymentFile}`)
  })
}
