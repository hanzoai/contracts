let Proxy    = artifacts.require('./test/TestProxy.sol')
let Delegate = artifacts.require('./test/TestDelegate.sol')


contract('Proxy', async () => {
  let delegate, proxy = null

  before(async () => {
    // Make sure our delegate and proxy are deployed
    delegate = await Delegate.deployed()
    proxy    = await Proxy.deployed()

    // Update proxy to point to delegate contract
    await proxy.setDelegate(delegate.address)

    // Use Delegate's ABI with proxy's address
    proxy = await Delegate.at(proxy.address)
  })

  it('should return static string from proxied method', async () => {
    let v = await proxy.staticString.call()
    assert.equal(v, 'bar', 'staticString() did not return expected string')
  })

  it('should return static address proxied method', async () => {
    let v = await proxy.staticAddress.call()
    assert(v.toLowerCase() === '0xdcad3a6d3569df655070ded06cb7a1b2ccd1d3af', 'staticAddress() did not return expected address')
  })

  it('should return static address from proxied method', async () => {
    let v = await proxy.staticNumber.call()
    assert(v.toNumber() === 42, 'staticNumber() did not return expected number')
  })

  it('should return static enum from proxied method', async () => {
    let v = await proxy.staticEnum.call()
    assert(v.toNumber() === 2, 'staticEnum() did not return expected enum')
  })

  it('should return static strings from proxied method', async () => {
    let res = await proxy.staticStrings.call()
    assert(res[0] === 'foo', 'staticStrings() did not return expected string for first return value')
    assert(res[1] === 'bar', 'staticStrings() did not return expected string for second return value')
  })

  it('should return static addresses from proxied method', async () => {
    let res = await proxy.staticAddresses.call()
    assert(res[0].toLowerCase() === '0xdcad3a6d3569df655070ded06cb7a1b2ccd1d3af', 'staticAddresses() did not return expected address for first return value')
    assert(res[1].toLowerCase() === '0x1c68f4f35ac5239650333d291e6ce7f841149937', 'staticAddresses() did not return expected address for second return value')
  })

  it('should return static numbers from proxied method', async () => {
    let res = await proxy.staticNumbers.call()
    assert(res[0].toNumber() === 42, 'staticNumbers() did not return expected number for first return value')
    assert(res[1].toNumber()  === 43, 'staticNumbers() did not return expected number for first return value')
  })

  it('should return mixed values from proxied method', async () => {
    let res = await proxy.staticMixed.call()
    assert(res[0].toNumber() === 42, 'staticMixed() did not return expected number for first return value')
    assert(res[1] === 'bar', 'staticMixed() did not return expected string for second return value')
  })
})
