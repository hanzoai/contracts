pragma solidity >=0.4.25 <0.6.0;


contract Proxy {
    address public delegate;

    // solium-disable
    // solhint-disable
    function () payable external {
        (bool ok,) = delegate.delegatecall(msg.data);
        require(ok);
        assembly {
            let outsize := returndatasize
            let outptr := mload(0x40) // Load memory
            mstore(0x40, add(outptr, outsize)) // Load up to return size
            returndatacopy(outptr, 0, outsize) // Copy last return into pointer
            return(outptr, outsize)
        }
    }
}
