let Whitelist = artifacts.require('./Whitelist.sol')


contract('Whitelist', async ([addr1, addr2]) => {
  let whitelist = null

  before(async () => {
    whitelist = await Whitelist.deployed()
  })

  it('should add address to whitelist', async () => {
    await whitelist.add(addr1)
    assert(await whitelist.isListed(addr1))
    assert(!await whitelist.isListed(addr2))
  })
})
