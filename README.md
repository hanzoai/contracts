<p align="center"><img src=".github/hero.svg" alt="contracts" width="880"></p>

# hanzo-solidity

[![npm][npm-img]][npm-url]
[![build][build-img]][build-url]
[![dependencies][dependencies-img]][dependencies-url]
[![downloads][downloads-img]][downloads-url]
[![license][license-img]][license-url]
[![chat][chat-img]][chat-url]

> Smart contracts developed for the [Hanzo Platform][hanzo]

This is a collection of [Solidity contracts][solidity] developed for the [Hanzo
Platform][hanzo]. Designed to meet a broad range of needs, our contracts play
well with [Truffle][truffle] and provide a cutting edge framework for contract
development.

## Install
```bash
$ npm install hanzo-solidity
```

## Usage
Import the contracts you want to use:

```solidity
import "hanzo-solidity/contracts/Versioned.sol";

contract Version {
    function version() public pure returns (string) {
        return "1.0.0";
    }

    function boolean() public pure returns (bool) {
        return true;
    }
}

contract Contract is Versioned {}
```

And interact with them as you would normally:


```javascript
let Contract = artifacts.require('./Contract.sol')
let Version  = artifacts.require('./Version.sol')

contract('Contract', async () => {
  let contract, version, proxy = null

  before(async () => {
    contract = await Contract.deployed()
    version  = await Version.deployed()
    await contract.setVersion(version.address)

    // Use current version's ABI and provide simple interface to a versioned
    // smart contract.
    proxy = await Version.at(contract.address)
  })

  it('should return result from proxied method', async () => {
    let v = await proxy.boolean.call()
    assert.equal(v, true, 'boolean() did not return expected boolean')
  })
})
```

You can find more examples of our contracts in use in our [test suite][tests].

# About Hanzo
[Hanzo][hanzo] enables businesses to launch and operate blockchain networks,
develop decentralized applications and deliver compelling experiences.

## License
[BSD][license-url]

[hanzo]:            https://hanzo.ai
[solidity]:         https://solidity.readthedocs.io
[truffle]:          http://truffleframework.com/
[tests]:            https://github.com/hanzoai/solidity/tree/master/test

[build-img]:        https://img.shields.io/travis/hanzoai/solidity.svg
[build-url]:        https://travis-ci.org/hanzoai/solidity
[chat-img]:         https://badges.gitter.im/join-chat.svg
[chat-url]:         https://gitter.im/hanzoai/solidity
[dependencies-img]: https://david-dm.org/hanzoai/solidity.svg
[dependencies-url]: https://david-dm.org/hanzoai/solidity
[downloads-img]:    https://img.shields.io/npm/dm/hanzo-solidity.svg
[downloads-url]:    http://badge.fury.io/js/hanzo-solidity
[license-img]:      https://img.shields.io/npm/l/hanzo-solidity.svg
[license-url]:      https://github.com/hanzoai/solidity/blob/master/LICENSE
[npm-img]:          https://img.shields.io/npm/v/hanzo-solidity.svg
[npm-url]:          https://www.npmjs.com/package/hanzo-solidity
