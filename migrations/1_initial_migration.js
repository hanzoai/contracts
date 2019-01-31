const Migrations = artifacts.require("./Migrations.sol") // Required by truffle

const TestDelegate   = artifacts.require("./test/TestDelegate.sol")
const TestProxy      = artifacts.require("./test/TestProxy.sol")
const TestVersion    = artifacts.require("./test/TestVersion.sol")
const TestVersioned  = artifacts.require("./test/TestVersioned.sol")
const Blacklist      = artifacts.require("./Blacklist.sol")
const Whitelist      = artifacts.require("./Whitelist.sol")

module.exports = (deployer) => {
    deployer.deploy(Migrations)
    deployer.deploy(TestDelegate)
    deployer.deploy(TestProxy)
    deployer.deploy(TestVersion)
    deployer.deploy(TestVersioned)
    deployer.deploy(Blacklist)
    deployer.deploy(Whitelist)
}
