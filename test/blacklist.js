let Blacklist = artifacts.require('./Blacklist.sol')


contract('Blacklist', async ([addr1, addr2]) => {
  let blacklist = null

  before(async () => {
    blacklist = await Blacklist.deployed()
  })

  it('should add address to blacklist', async () => {
    await blacklist.add(addr1)
    assert(await blacklist.isListed(addr1))
    assert(!await blacklist.isListed(addr2))
  })
})
