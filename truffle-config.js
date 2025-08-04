require('dotenv').config()
const HDWalletProvider = require('@truffle/hdwallet-provider')
const utils = require('web3-utils')

module.exports = {
  /**
   * Networks define how you connect to your ethereum client and let you set the
   * defaults web3 uses to send transactions. If you don't specify one truffle
   * will spin up a development blockchain for you on port 9545 when you
   * run `develop` or `test`. You can ask a truffle command to use a specific
   * network from the command line, e.g
   *
   * $ truffle test --network <network-name>
   */

  networks: {
    development: {
      host: '127.0.0.1', // Localhost (default: none)
      port: 8545, // Standard Ethereum port (default: none)
      network_id: '*', // Any network (default: none)
    },
    etntest: {
      provider: () =>
        new HDWalletProvider(process.env.PRIVATE_KEY, 'https://rpc.ankr.com/electroneum_testnet'),
      network_id: 5201420,
      gas: 28000000,
      gasPrice: utils.toWei('2', 'gwei'),
      skipDryRun: true,
    },
    etnmain: {
      provider: () => new HDWalletProvider(process.env.PRIVATE_KEY, 'https://rpc.ankr.com/electroneum'),
      network_id: 52014,
      gas: 28000000,
      gasPrice: utils.toWei('2', 'gwei'),
      skipDryRun: true,
    },
  },

  mocha: {
    // timeout: 100000
  },

  // Configure your compilers
  compilers: {
    solc: {
      version: '0.7.6',
      settings: {
        optimizer: {
          enabled: true,
          runs: 200,
        },
        outputSelection: {
          '*': {
            '*': ['*', 'metadata'],
          },
        },
        // Include source code in the metadata
        metadata: {
          useLiteralContent: true,
        },
      },
    },
    external: {
      command: 'node ./scripts/compileHasher.js',
      targets: [
        {
          path: './build/Hasher.json',
        },
      ],
    },
  },

  plugins: ['solidity-coverage'],
}
