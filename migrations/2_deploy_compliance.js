/* eslint-disable indent */
/* global artifacts, web3 */
const fs = require('fs')
const path = require('path')

const ComplianceRegistry = artifacts.require('ComplianceRegistry')
const MishMashRouterV2 = artifacts.require('MishMashRouterV2')
const CompliantETNMishMashProposal = artifacts.require('CompliantETNMishMashProposal')

const deploymentsDir = path.join(__dirname, '..', 'deployments')
const sanctionListPath = path.join(__dirname, '..', 'scripts', 'sanction_events.json')

module.exports = function (deployer) {
  return deployer.then(async () => {
    const chainId = await web3.eth.getChainId()

    let previousDeployment = getPreviousDeployment(chainId)

    if (!previousDeployment) {
      console.log(`No previous deployment found for chainId ${chainId}`)
      return
    }

    const sanctionList = JSON.parse(fs.readFileSync(sanctionListPath, 'utf8'))
    if (!sanctionList) {
      console.error('No sanction list found. Run fetchChainalysisSanctioned.js to get the list.')
      return
    }

    const netSanctionedAddresses = sanctionList.netSanctionedAddresses

    // ComplianceRegistry
    const complianceRegistry = await deployer.deploy(
      ComplianceRegistry,
      previousDeployment.contracts.GovernanceProxy.address,
      netSanctionedAddresses,
      'Chainalysis Sanction List (2025-08-26)',
    )
    previousDeployment.contracts.ComplianceRegistry = await getContractInfo(complianceRegistry)

    // ROUTER PROXY
    const mishMashRouterV2 = await deployer.deploy(
      MishMashRouterV2,
      previousDeployment.contracts.GovernanceProxy.address,
      previousDeployment.contracts.InstanceRegistryProxy.address,
      previousDeployment.contracts.RelayerRegistryProxy.address,
      previousDeployment.contracts.ComplianceRegistry.address,
    )
    previousDeployment.contracts.MishMashRouterV2 = await getContractInfo(mishMashRouterV2)

    // Compliant Instance Proposal
    const compliantInstanceProposal = await deployer.deploy(
      CompliantETNMishMashProposal,
      previousDeployment.contracts.Verifier.address,
      previousDeployment.contracts.Hasher.address,
      previousDeployment.contracts.ComplianceRegistry.address,
    )
    previousDeployment.contracts.CompliantInstanceProposal = await getContractInfo(compliantInstanceProposal)

    // Save deployment addresses to timestamped JSON file
    if (!fs.existsSync(deploymentsDir)) {
      fs.mkdirSync(deploymentsDir, { recursive: true })
    }

    const timestamp = new Date().toISOString().replace(/[:.]/g, '-')
    const deploymentFile = path.join(deploymentsDir, `deployment_${timestamp}.json`)

    fs.writeFileSync(deploymentFile, JSON.stringify(previousDeployment, null, 2))
    console.log(`Deployment addresses saved to: ${deploymentFile}`)
  })
}

function getPreviousDeployment(chainId) {
  if (fs.existsSync(deploymentsDir)) {
    const deploymentFiles = fs
      .readdirSync(deploymentsDir)
      .filter((file) => file.startsWith('deployment_') && file.endsWith('.json'))
      .map((file) => ({
        filename: file,
        filepath: path.join(deploymentsDir, file),
        timestamp: fs.statSync(path.join(deploymentsDir, file)).mtime.getTime(),
      }))
      .sort((a, b) => b.timestamp - a.timestamp) // Sort by most recent first

    // Find the most recent deployment with matching chainId
    for (const deploymentFile of deploymentFiles) {
      try {
        const deploymentData = JSON.parse(fs.readFileSync(deploymentFile.filepath, 'utf8'))
        if (deploymentData.network === chainId.toString()) {
          console.log(`Found previous deployment for chainId ${chainId}: ${deploymentFile.filename}`)
          return deploymentData
        }
      } catch (error) {
        console.warn(`Failed to parse deployment file ${deploymentFile.filename}:`, error.message)
      }
    }

    return undefined
  }
}

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
