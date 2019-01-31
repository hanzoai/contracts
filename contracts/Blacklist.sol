pragma solidity >=0.4.25 <0.6.0;

import "openzeppelin-solidity/contracts/ownership/Ownable.sol";


contract Blacklist is Ownable {
    mapping (address => bool) blacklist;
    uint length;

    event BlacklistAdded(address indexed addr);
    event BlacklistRemoved(address indexed addr);

    constructor() Ownable() public {}

    function add(address addr) public onlyOwner {
        require(addr != address(0));
        blacklist[addr] = true;
        length++;
        emit BlacklistAdded(addr);
    }

    function remove(address addr) public onlyOwner {
        require(addr != address(0));
        blacklist[addr] = false;
        length--;
        emit BlacklistRemoved(addr);
    }

    function isListed(address addr) public view returns (bool) {
        require(addr != address(0));
        if (length == 0) {
            return false;
        }
        return blacklist[addr];
    }
}
