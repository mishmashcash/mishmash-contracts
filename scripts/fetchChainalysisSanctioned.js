const Web3 = require('web3')
const fs = require('fs')
const path = require('path')

// Event signatures for Sanction-related events
const EVENT_SIGNATURES = {
  SANCTIONED_ADDRESSES_ADDED: 'SanctionedAddressesAdded(address[])',
  SANCTIONED_ADDRESSES_REMOVED: 'SanctionedAddressesRemoved(address[])',
}

// Calculate event topic hashes
const EVENT_TOPICS = {
  SANCTIONED_ADDRESSES_ADDED: Web3.utils.keccak256(EVENT_SIGNATURES.SANCTIONED_ADDRESSES_ADDED),
  SANCTIONED_ADDRESSES_REMOVED: Web3.utils.keccak256(EVENT_SIGNATURES.SANCTIONED_ADDRESSES_REMOVED),
}

class SanctionEventFetcher {
  constructor(rpcUrl) {
    this.web3 = new Web3(rpcUrl)
    this.results = {
      successful: [],
      failed: [],
      sanctionEvents: [],
    }
  }

  /**
   * Fetch logs for a single transaction
   * @param {string} txHash - Transaction hash
   * @returns {Promise<Object>} - Transaction logs and metadata
   */
  async fetchTransactionLogs(txHash) {
    try {
      // Get transaction receipt
      const receipt = await this.web3.eth.getTransactionReceipt(txHash)

      if (!receipt) {
        throw new Error('Transaction not found')
      }

      const result = {
        txHash,
        blockNumber: receipt.blockNumber,
        sanctionEvents: [],
      }

      // Filter for Sanction events
      result.sanctionEvents = this.filterSanctionEvents(receipt.logs)

      return result
    } catch (error) {
      return {
        txHash,
        error: error.message,
        sanctionEvents: [],
      }
    }
  }

  /**
   * Filter logs for Sanction-related events
   * @param {Array} logs - Array of log objects
   * @returns {Array} - Filtered Sanction events
   */
  filterSanctionEvents(logs) {
    const sanctionEvents = []

    for (const log of logs) {
      const topic0 = log.topics[0]

      if (topic0 === EVENT_TOPICS.SANCTIONED_ADDRESSES_ADDED) {
        sanctionEvents.push({
          type: 'SanctionedAddressesAdded',
          contractAddress: log.address,
          blockNumber: log.blockNumber,
          transactionHash: log.transactionHash,
          logIndex: log.logIndex,
          addresses: this.decodeAddressArray(log.data),
        })
      } else if (topic0 === EVENT_TOPICS.SANCTIONED_ADDRESSES_REMOVED) {
        sanctionEvents.push({
          type: 'SanctionedAddressesRemoved',
          contractAddress: log.address,
          blockNumber: log.blockNumber,
          transactionHash: log.transactionHash,
          logIndex: log.logIndex,
          addresses: this.decodeAddressArray(log.data),
        })
      }
    }

    return sanctionEvents
  }

  /**
   * Decode an array of addresses from log data
   * @param {string} data - Hex encoded log data
   * @returns {Array} - Array of decoded addresses
   */
  decodeAddressArray(data) {
    try {
      // Remove '0x' prefix and decode
      const hexData = data.slice(2)

      // The next 32 bytes contain the length of the array
      const length = parseInt(hexData.slice(64, 128), 16)

      const addresses = []

      // Each address is 32 bytes (padded to 32 bytes)
      for (let i = 0; i < length; i++) {
        const startIndex = 128 + i * 64 // 64 hex chars = 32 bytes
        const addressHex = hexData.slice(startIndex, startIndex + 64)

        // Convert to address format (last 20 bytes)
        const address = '0x' + addressHex.slice(24) // Remove padding
        addresses.push(Web3.utils.toChecksumAddress(address))
      }

      return addresses
    } catch (error) {
      console.error('Error decoding address array:', error)
      return []
    }
  }

  /**
   * Fetch logs for multiple transactions and build net sanctioned address list
   * @param {Array} txHashes - Array of transaction hashes
   * @returns {Promise<Object>} - Results object with net sanctioned addresses
   */
  async fetchMultipleTransactionLogs(txHashes) {
    const sanctionedAddresses = new Set()
    const results = {
      successful: [],
      failed: [],
      sanctionEvents: [],
    }

    // Process transactions in chronological order
    for (let i = 0; i < txHashes.length; i++) {
      const txHash = txHashes[i]
      const txResult = await this.fetchTransactionLogs(txHash)

      if (txResult.error) {
        results.failed.push(txResult)
      } else {
        results.successful.push(txResult)
        results.sanctionEvents.push(...txResult.sanctionEvents)

        // Process Sanction events to build net sanctioned address list
        for (const event of txResult.sanctionEvents) {
          if (event.type === 'SanctionedAddressesAdded') {
            event.addresses.forEach((addr) => sanctionedAddresses.add(addr))
          } else if (event.type === 'SanctionedAddressesRemoved') {
            event.addresses.forEach((addr) => sanctionedAddresses.delete(addr))
          }
        }
      }
    }

    results.netSanctionedAddresses = Array.from(sanctionedAddresses).sort()
    return results
  }

  /**
   * Save results to JSON file
   * @param {Object} results - Results object
   * @param {string} filename - Output filename
   */
  saveResults(results, filename = 'sanction_events.json') {
    const outputPath = path.join(__dirname, filename)

    const output = {
      timestamp: new Date().toISOString(),
      summary: {
        totalTransactions: results.successful.length + results.failed.length,
        successfulTransactions: results.successful.length,
        failedTransactions: results.failed.length,
        totalSanctionEvents: results.sanctionEvents.length,
        netSanctionedAddresses: results.netSanctionedAddresses.length,
      },
      netSanctionedAddresses: results.netSanctionedAddresses,
      sanctionEvents: results.sanctionEvents,
      successful: results.successful,
      failed: results.failed,
    }

    fs.writeFileSync(outputPath, JSON.stringify(output, null, 2))
    console.log(`Results saved to: ${outputPath}`)
    console.log(`Net sanctioned addresses: ${results.netSanctionedAddresses.length}`)
  }
}

// TX Hashes for Chainalysis Sanction Events as of 2025-08-26
const txHashes = [
  '0x1d3d64b26cfdaeb328d01d09b407f3a806d3254109e4476461b3960592eae902',
  '0xe3c89f573682122446749d87286096bbe66f3efccde1480f58e61ce4273726fa',
  '0xf7da9ad1dc31c0a5ad771ee8ef93f36ec9b4edce6e6cbc273b0e900ebe898800',
  '0x05aa41b16c7a863e5497ab9bf3273154ac7fdb80370035d624e32198e2e1277f',
  '0xc9d7b45c94a5b78e940c98d1f25818788decaa583042f229f97a9cea194d5e18',
  '0x9e4adac535ea92cd81ef33a9571629dd8ab2ca1a0042c3f21a2e3e76901791b1',
  '0xfc6b06392e8e1431e2c9d987b0fda7bc5c8a4e2e4b99ec986174d6935f822f6b',
  '0xb3754ca28e49008e869da4495a196b974e5a3bdce5ca05deaff1737f606d5bdb',
  '0x3bae678feffd8a95e96df42b7eec557e9c390373d2929a2f2214fb5bb603206c',
  '0x97f990a89bce879cacfb196a54737bad8a0cb3136cde6eca283890ceb2fe4a51',
  '0xe99daa5bf045919eb74f79e7f1831c00016d380e8749e7d07d5f0299a0ab7833',
  '0x42e0c20aa1607afab649fe4834c2c96ae205c67196f138f281234028d494ac98',
  '0x17ed5a4113a651cc2306314ddaea276d08f37268a49232b94b7a0d17f60486eb',
  '0x421b8ea7301bec4cad40a13f5ff288f61bd21c57c9bf4a21258d8b0974a94490',
  '0x2f938ecf08677602bd4cd2b7d43da934f839fea746cb3c8e95ed135efb7a4258',
  '0x15882c6f3ea8d9be435385b6a37e633e0b6381eb6c3a71d3f72d8271ec8638ea',
  '0x3676d144ce86481668650f1c60da3f78cbf85f5862c6b0409a44035f971f55a8',
  '0x624f722fe728d3ee244801e691108f2fa7a15209fa197b7973af523b948fabd8',
  '0x50f2b4936ca0dcc5baacfc2add6e842b7b9f246629cdb9df8a924c708fccd130',
  '0x4430bf9af79d9b9c403ab47a0526d53fb0faa7340cb5916763b3699122e7c729',
  '0xccb787381b01b390d82a651714eb58711bd69d27a4494d366416b31fde0804c5',
  '0x4c49c6a62d701983bd21cc143d26f1195671aa3d6902043c83ee0755937e2973',
  '0xdfc79b3fbe6e4ea7929ff44cdbede3ef6cba497b1c8f9fd4012403100efebc49',
  '0x7bab67582117fb64d6f3926da2af55206f972cef3dd68640501ad0e6d8c50920',
  '0x4afc7154e2c48183667979ea2c88bada74228bc4dc6f8e2f5e65509caf0f30c5',
  '0x79e496c2dae0219175583fd4cfad08c1650c92fb8a726b496b81dee077d01f50',
  '0x94234d073184e11a8da55e9ce4c7684dacc046c1a9eb674ca0195ba7c3fb0b53',
  '0x1bded7ec8753315d49ff688d16e283d110730690c7f8f5526f634aeeabc0006b',
  '0xee7de52ba88f098337845c96a5c98a2ca3dbdb22018299c6f43a8b286ffd4a77',
  '0xeb1a810d440175c61fe529394cfed0b558614ee191a9cd90c3c39af6d876e5ab',
  '0x92a731f698d9c61ad43ef35675e81aba410075452126ff419201fd104c480473',
  '0x76b9656a96e713f0aa207acb184530a508a97e0cfcad1540d594d4a45de484e7',
  '0x9a421191f7ca5a22b4a166886370917d019e148c0356900de12047a734da0561',
  '0x1dcdc6b09194503b1426b94564310ebcaad2c3ddaf3951b331b8834f734ba3e0',
  '0xbb8ab9c56cb51727cdf1046a7a998d2b25ae831dfef014e108b5d6eaffef3ac0',
  '0xd7051c81ef81174d2f2ab0fde95bd0a3d5c79a3d8d08b72dbe5553b7186d3b27',
  '0x9cfbcab760ea4fd685034c253ddadca55036280505121d7f2aa89d650308b875',
  '0xa2145df140a932f355c52c3be9b674afb1d3068679c69915603db11738f1f5b9',
  '0xd6b9396fea05e5ee1ad819002871e7ab54478dea89c16ce0491915bbf94dfea9',
  '0x7a61100f5b06d1a9b0e4556630986823f9ef97f9a1cea14caf28e2989a5db3e8',
  '0x0f1f18899f5a0d7bcaaf2aa6babf5d0d1f59a62ecd14ddc2881227bf523c16b0',
  '0xc4d350f935bd44176db6596b42e9e2a340c9d1bccb465e2d765d287e6ded0ece',
  '0x5df2467e5ea076c25890434b92eeb59c642fe708c6717b714319edf6eac16f07',
  '0x1fb6ae1af08aa0924be39ed86007f3e582947aec5ee911e8d0485b8c35afe7ad',
  '0x92e6c67478412c7c6c480976dfc1236adf84ab30e253bbb520aca2e95669280c',
  '0xf35549298445c2ec40b98e7e6c50f9d4926d3950e23e0b76cedcd0c8b7ffd1cf',
  '0xf5190c48999aad2945ae356b6b9069aea9dd2d6286fb60bd966cb5042c8bca85',
  '0x4a3e8be99262156e3e20c7bf79d57b1acd973845a4153bd7f88e4ed375bd57ad',
  '0xf5e2734393ee064a51b13e4ad717128b7fafead7ee975455107d6cb945e24011',
  '0x1c6ff0f3228460a35595ba73aef70ec7df5063fca24d1567bc3127490931cda7',
  '0x4ecadd3313e1e8c5db0ea45143b47986c90f1b86372e4a559bbca4cfb92ddc4c',
  '0xaef4af4268d9ee47fb03e7c28fb4cf1c9f9d2055952703c0c2c8c16cbbce00e6',
  '0xdff7a51378b999af1f425b25fe1500f53afe78d693b6597af2e16ddd6334c604',
  '0x2e08049dc7b9204b11403dfd80d987e4a47d2e1fad529eaa968d8b130e93dcee',
  '0xc2b3e53f0fddb82cbd1dc68413e1216e7a355ca42aa978a2dfb6d1f010fb4334',
  '0xd74753339659e94d44b45658f15880b531e5396f6138e099528ae51468895084',
  '0x8459bd82b0a2b46fcaa843c33d5217bd983314b03432031e2be9fb515610f3f9',
  '0x128c422516d683a9dfc9e917abaa9500179757270824d9c0e5940dbce00784eb',
  '0x0708a30a4099ae82d0c9d90092849cf5f806b86238ca2f1d5d3beaf857cf89af',
  '0xab4383f727fb5945be0b75531270df254a45c33e1cbf8b12f55dba0d14913fae',
  '0x83d6e9d224a6bb9ab0627258bacd1ee0b7a595f9993e4e79f5700bc5ffecb445',
  '0x2b0e99821e1d0d3f1e75c103c6276565cf45a34b933b52411051d1b7fb779188',
  '0x37ef4ce0525091f884c00abc7c86ea7c2488ea370328742f249b850ae41feef7',
  '0x8d923cad83c33ee0492f29d896b99f59183534b972060dfd168e59d6b16c3b49',
  '0x869b776f3d6f1263f3ea238d6b247e1e7e9eb891a8c17bb2202af3d80d5ab54a',
  '0x31c89eddb2190abed62b17e6a2a9f56a409898498658f42e7c8fa4b48195809f',
  '0x0c3335cd81db77e89c5265ac9758c1f904181d8924260fbfe57f1fe99bc18dee',
  '0x87f66624b6174d0f4274353cbd93a217383d17f3da62c0594315a9bb45b3fa78',
  '0x12dac0c42dc782c2b19171414712ffa3ab838e79b5b2c86ab7fbf004e1ccf9b5',
  '0x4e164e83e17fa8e44918a1bcde5db04113362e28d05749398bc9097650b4d1cc',
  '0x82e81e00ae25ca89d23f726709b827056addd11f40231b2e24f8e097f7687af9',
  '0x8eab4d9cf47d10b0c3075c01cd9300d2461090e35dd5255c6ffb084baa2298b2',
  '0x2f003383cf9edbdaeead05c80788da5894db438401793708af4b1b7005da3c8a',
  '0x57f4cdef020828cdc81db1c988c391dc2bfe4da1e419d21eae25899fea8c8912',
  '0x68303aa14e6e32deb044cdfe15f034f060f85aa971e07f98c90c00ddb283ef2e',
  '0xa7b9cff7f34bc3642ec27513c70fb1f28dcd1de9b40a9297065ee7176b6deed5',
  '0x7cc995252a9da4ce4f08d32a2b9a6ceede7258412b025fad07067c47b5110c55',
  '0x9da9c2d5033200548dc370fca21506f47bf3e987b4cda5e372952c3be132460c',
  '0x7e1771f3798da1980840bb8c66524667bdb5be1e1447c7127c6b631f2fcfacb0',
  '0xa2c14db7f1a255fbb6434b9a829b5cf2759d1637ef46e4ad2d1cd9391f4ae263',
  '0x4acf430775d025f18b53f77a2a9d962ad6aae85e99c7ab2e801e6204831be807',
  '0x5d5f9971c3ce1f2cce81bff936a64e117846e41f960534fb979098e2cbb25728',
  '0xde9959ccafb8e3282a85aebad93dbeb72d19b94deb7accbde78caf701d59d27c',
  '0x9fcf8b1942c0d21a1794d61f4833988ce84ce1f58a6c9cac75206c9f8771b769',
  '0xeca25e73a3637f73f742441966e9fecb5bb76bfa2be999d7b2247d0405d473f9',
  '0x75f213aa421ca2bf728b1b90f9e08dba038708d5483dac1292a501e9406251d4',
  '0xe545b60e07fa17e4d1f60a75792c3e0e5b3a5534fd0f88bff73d960922352301',
  '0x149024732f2aa0d0b8aa2a6b027575e49e1d86164772bae2197baac6e96638ba',
  '0x7af621eac1384afac8e4134251a7eecaf1383b2c66f812e3cd4736b3ad3aa50b',
  '0x9af8f9b5506799122f2ddf3617a2e7aa144293a90c9b5f6b36f1af6ee00b942e',
]

// CLI usage
async function main() {
  const rpcUrl = 'https://rpc.ankr.com/eth'

  const fetcher = new SanctionEventFetcher(rpcUrl)

  try {
    console.log(`Processing ${txHashes.length} transactions...`)
    const results = await fetcher.fetchMultipleTransactionLogs(txHashes)
    fetcher.saveResults(results)

    // Print the net sanctioned addresses
    if (results.netSanctionedAddresses.length > 0) {
      console.log('\nNet sanctioned addresses:')
      results.netSanctionedAddresses.forEach((addr) => console.log(addr))
    } else {
      console.log('\nNo net sanctioned addresses found.')
    }
  } catch (error) {
    console.error('Error:', error)
    process.exit(1)
  }
}

// Export for use as module
module.exports = SanctionEventFetcher

// Run if called directly
if (require.main === module) {
  main()
}
