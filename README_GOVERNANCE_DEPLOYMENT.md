# Governance Deployment Guide

This guide explains how to deploy the governance system using the LoopbackProxy pattern.

## Overview

The deployment process involves:
1. Deploying an InitialGovernance contract (placeholder)
2. Deploying the LoopbackProxy with the initial governance as logic
3. Upgrading the proxy to point to the actual Governance contract
4. Updating the governance with correct dependency addresses

## Deployment Steps

### Step 1: Deploy Initial Governance and Proxy

Run the first migration to deploy the initial governance and proxy:

```bash
truffle migrate --f 0 --to 0 --network <network>
```

This will:
- Deploy InitialGovernance (placeholder contract)
- Deploy LoopbackProxy with InitialGovernance as logic
- Deploy actual Governance with placeholder addresses
- Upgrade proxy to point to actual Governance

### Step 2: Deploy Dependencies

Deploy all the dependency contracts (userVault, gasCompVault, staking, torn, etc.) in the correct order as outlined in the dependency analysis.

### Step 3: Update Governance Addresses

After all dependencies are deployed, update the governance with the correct addresses using the helper script:

```bash
truffle exec scripts/updateGovernanceAddresses.js <userVault> <gasCompVault> <staking> <tornToken> --network <network>
```

Or set environment variables and run:

```bash
export USER_VAULT_ADDRESS=0x...
export GAS_COMPENSATION_VAULT_ADDRESS=0x...
export STAKING_REWARDS_ADDRESS=0x...
export TORN_TOKEN_ADDRESS=0x...

truffle exec scripts/updateGovernanceAddresses.js --network <network>
```

## Contract Addresses

After deployment, you'll have these key addresses:

- **LoopbackProxy**: The main governance address (use this for all interactions)
- **Governance Implementation**: The actual governance logic contract
- **InitialGovernance**: The placeholder contract (no longer used)

## Usage

### Interacting with Governance

Always interact with governance through the proxy address:

```javascript
const Governance = artifacts.require('Governance')
const governance = await Governance.at(proxyAddress)

// Use governance functions
await governance.propose(target, description)
await governance.castVote(proposalId, support)
```

### Verifying Deployment

Check that the deployment worked correctly:

```javascript
const governance = await Governance.at(proxyAddress)
const version = await governance.version()
console.log('Governance version:', version) // Should be "3.consolidated-governance"
```

## Migration Files

- `0_deploy_governance.js`: Deploys InitialGovernance, LoopbackProxy, and upgrades to actual Governance
- `1_update_governance_addresses.js`: Updates governance with correct dependency addresses (optional)

## Helper Scripts

- `scripts/updateGovernanceAddresses.js`: Helper script to update governance addresses after all dependencies are deployed

## Security Considerations

1. **Proxy Admin**: The LoopbackProxy sets its admin to the implementation itself
2. **Self-Upgrade**: The governance contract can upgrade itself through proposals
3. **Address Verification**: Always verify addresses before updating governance
4. **Testing**: Test the deployment on a testnet before mainnet

## Troubleshooting

### Common Issues

1. **Initialization Failed**: Check that init data is correctly encoded
2. **Proxy Admin Mismatch**: Verify admin is set to implementation address
3. **Address Updates**: Ensure all dependency addresses are correct before updating governance
4. **Storage Layout**: Ensure new implementation has compatible storage layout

### Verification

```javascript
// Verify proxy deployment
const proxy = await LoopbackProxy.deployed()
const admin = await proxy.admin()
const implementation = await proxy.implementation()

console.log('Proxy Admin:', admin)
console.log('Implementation:', implementation)
```

## LoopbackProxy Benefits

1. **Self-Upgrade Capability**: Governance can upgrade itself through proposals
2. **Clean Separation**: Logic and proxy are separate contracts
3. **Upgrade Safety**: Only governance proposals can trigger upgrades
4. **Admin Control**: The proxy admin is the implementation itself

The LoopbackProxy pattern ensures that the governance system can be upgraded while maintaining security and control over the upgrade process. 