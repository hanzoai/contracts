pragma solidity >=0.4.25 <0.6.0;

import "../Proxy.sol";


contract TestProxy is Proxy {
    function setDelegate(address _delegate) public {
        delegate = _delegate;
    }
}
