pragma solidity >=0.4.25 <0.6.0;


contract TestDelegate {
    address constant private TEST_ADDRESS = 0xdCad3a6d3569DF655070DEd06cb7A1b2Ccd1D3AF;
    address constant private OTHER_ADDRESS = 0x1C68f4f35AC5239650333D291E6ce7f841149937;

    enum Choices {UpHigh, DownLow, TooSlow}

    function staticString() public pure returns (string memory) {
        return "bar";
    }

    // Fun note. This will return outside of the blockchain with all the
    // characters in the address lowercased. The difference is harmless, as
    // case sensitivity isn't a thing for addresses, but .toLower() is implicit
    // here.
    function staticAddress() public pure returns (address) {
        return TEST_ADDRESS;
    }

    // In Javascript, this ends up becoming a BigNumber object to deal with all
    // of the potential numeric returns from the blockchain. Check this stack
    // exchange question for more info:
    // https://ethereum.stackexchange.com/questions/7656/what-are-c-e-and-s-properties-in-message-call-return-object
    function staticNumber() public pure returns (uint) {
        return 42;
    }

    // Since enum types are not part of the ABI, the signature of "getChoice"
    // will automatically be changed to "staticChoice() returns (uint8)"
    // for all matters external to Solidity. The integer type used is just
    // large enough to hold all enum values, i.e. if you have more values,
    // `uint16` will be used and so on. The indexing starts from 0.
    // As a corrolary, because they're returned as numbers, in Javascript they
    // also become BigNumber objects as well. See the stack exchange link
    // above.
    function staticEnum() public pure returns (Choices) {
        return Choices.TooSlow;
    }

    // This will only work when invoked off the blockchain.
    // Contract-to-contract, only static length types are accepted.
    function staticStrings() public pure returns (string memory, string memory) {
        return ("foo", "bar");
    }

    function staticAddresses() public pure returns (address, address) {
        return (TEST_ADDRESS, OTHER_ADDRESS);
    }

    function staticNumbers() public pure returns (uint, uint) {
        return (42, 43);
    }

    function staticMixed() public pure returns (uint, string memory) {
        return (42, "bar");
    }

    // Compiler complains that this method signature "doesn't exist or not
    // unique". So - returning two enums from a function isn't possible right
    // now. Go figure.
    // function staticEnums() public pure returns (Choice, Choice) {
    //     return (Choices.UpHigh, Choices.DownLow);
    // }
}
