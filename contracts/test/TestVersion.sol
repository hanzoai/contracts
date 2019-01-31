pragma solidity >=0.4.25 <0.6.0;


contract TestVersion {
    function version() public pure returns (string memory) {
        return "1.0.0";
    }

    function boolean() public pure returns (bool) {
        return true;
    }
}
