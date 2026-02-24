// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/AIToken.sol";
import "../src/identity-registry/HanzoRegistry.sol";
import "../src/AIFaucet.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title DeployIdentitySystem
 * @dev Deploy complete identity system: AIToken, HanzoRegistry, AIFaucet
 *
 * Usage:
 * forge script script/DeployIdentitySystem.s.sol:DeployIdentitySystem --rpc-url $RPC_URL --broadcast
 *
 * Networks:
 * - Hanzo Mainnet: --rpc-url https://rpc.hanzo.ai
 * - Hanzo Testnet: --rpc-url https://testnet-rpc.hanzo.ai
 * - Lux Mainnet: --rpc-url https://api.lux.network/ext/bc/C/rpc
 * - Zoo Mainnet: --rpc-url https://rpc.zoo.network
 */
contract DeployIdentitySystem is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("Deploying from:", deployer);
        console.log("Chain ID:", block.chainid);

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy AIToken
        address treasury = deployer; // Can be changed to multisig later
        AIToken aiToken = new AIToken(treasury);
        console.log("AIToken deployed at:", address(aiToken));

        // 2. Deploy HanzoNft placeholder (simplified ERC721)
        HanzoNft hanzoNft = new HanzoNft();
        console.log("HanzoNft deployed at:", address(hanzoNft));

        // 3. Deploy HanzoRegistry implementation
        HanzoRegistry registryImpl = new HanzoRegistry();
        console.log("HanzoRegistry implementation:", address(registryImpl));

        // 4. Deploy proxy for HanzoRegistry
        bytes memory initData = abi.encodeWithSelector(
            HanzoRegistry.initialize.selector,
            deployer,
            address(aiToken),
            address(hanzoNft)
        );

        ERC1967Proxy registryProxy = new ERC1967Proxy(
            address(registryImpl),
            initData
        );
        console.log("HanzoRegistry proxy:", address(registryProxy));

        // 5. Deploy AIFaucet
        uint256 dripAmount = 100 * 1e18; // 100 AI tokens
        uint256 cooldownPeriod = 24 hours;
        uint256 maxDailyLimit = 500 * 1e18; // 500 AI tokens per day max

        AIFaucet faucet = new AIFaucet(
            address(aiToken),
            dripAmount,
            cooldownPeriod,
            maxDailyLimit
        );
        console.log("AIFaucet deployed at:", address(faucet));

        // 6. Transfer some AI tokens to faucet for initial distribution
        uint256 faucetInitialBalance = 100000 * 1e18; // 100k AI tokens
        aiToken.transfer(address(faucet), faucetInitialBalance);
        console.log("Transferred", faucetInitialBalance / 1e18, "AI tokens to faucet");

        // 7. Grant HanzoRegistry permission to mint NFTs
        hanzoNft.grantMinterRole(address(registryProxy));
        console.log("Granted minter role to registry");

        vm.stopBroadcast();

        // Print deployment summary
        console.log("\n=== Deployment Summary ===");
        console.log("Network Chain ID:", block.chainid);
        console.log("Deployer:", deployer);
        console.log("AIToken:", address(aiToken));
        console.log("HanzoNft:", address(hanzoNft));
        console.log("HanzoRegistry (Proxy):", address(registryProxy));
        console.log("HanzoRegistry (Implementation):", address(registryImpl));
        console.log("AIFaucet:", address(faucet));
        console.log("Faucet drip amount:", dripAmount / 1e18, "AI");
        console.log("Faucet cooldown:", cooldownPeriod / 3600, "hours");
    }
}

/**
 * @dev Simple NFT contract for identity binding
 */
contract HanzoNft {
    uint256 private _tokenIdCounter;
    mapping(uint256 => address) private _owners;
    mapping(address => bool) public minters;
    address public owner;

    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    constructor() {
        owner = msg.sender;
        minters[msg.sender] = true;
    }

    modifier onlyMinter() {
        require(minters[msg.sender], "Not a minter");
        _;
    }

    function grantMinterRole(address minter) external {
        require(msg.sender == owner, "Not owner");
        minters[minter] = true;
    }

    function mint(address to) external onlyMinter returns (uint256) {
        uint256 tokenId = _tokenIdCounter++;
        _owners[tokenId] = to;
        emit Transfer(address(0), to, tokenId);
        return tokenId;
    }

    function burn(uint256 tokenId) external {
        require(_owners[tokenId] == msg.sender, "Not owner");
        delete _owners[tokenId];
        emit Transfer(msg.sender, address(0), tokenId);
    }

    function ownerOf(uint256 tokenId) external view returns (address) {
        return _owners[tokenId];
    }
}
