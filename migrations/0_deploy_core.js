/* global artifacts */
const Hasher = artifacts.require('Hasher')
const Verifier = artifacts.require('Verifier')

module.exports = function (deployer) {
  return deployer.then(async () => {
    await deployer.deploy(Hasher)
    await deployer.deploy(Verifier)
  })
}
