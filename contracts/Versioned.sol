pragma solidity >=0.4.25 <0.6.0;

import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "./Proxy.sol";


interface Version {
    function version() external pure returns (string memory);
}


contract Versioned is Ownable, Proxy {
    event Upgrade(string version, address indexed predecessor, address indexed successor);

    // Update current version and store method configurations
    function setVersion(Version successor) public onlyOwner {
        address predecessor = delegate;
        delegate = address(successor);
        emit Upgrade(successor.version(), predecessor, delegate);
    }
}
