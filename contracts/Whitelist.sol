pragma solidity >=0.4.25 <0.6.0;

import "openzeppelin-solidity/contracts/ownership/Ownable.sol";


contract Whitelist is Ownable {
    mapping (address => bool) whitelist;
    uint length;

    event WhitelistAdded(address indexed addr);
    event WhitelistRemoved(address indexed addr);

    constructor() Ownable() public {}

    function add(address addr) public onlyOwner {
        require(addr != address(0));
        whitelist[addr] = true;
        length++;
        emit WhitelistAdded(addr);
    }

    function remove(address addr) public onlyOwner {
        require(addr != address(0));
        whitelist[addr] = false;
        length++;
        emit WhitelistRemoved(addr);
    }

    function isListed(address addr) public view returns (bool) {
        require(addr != address(0));
        if (length == 0) {
            return false;
        }
        return whitelist[addr];
    }
}
