// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface HanzoTokenInterface is IERC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function transfer(address recipient, uint256 amount) external returns (bool);
}

interface HanzoNftInterface {
    function mint(address to) external returns (uint256);
    function burn(uint256 tokenId) external;
    function ownerOf(uint256 tokenId) external view returns (address);
}

/**
 * @title HanzoRegistry
 * @dev Multi-network identity registry for Hanzo, Lux, and Zoo ecosystems
 *
 * Supported networks:
 * - Hanzo mainnet (36963) / testnet (36962)
 * - Lux mainnet (96369) / testnet (96368)
 * - Zoo mainnet (200200) / testnet (200201)
 * - Sepolia testnet
 * - Arbitrum Sepolia testnet
 */
contract HanzoRegistry is Initializable, UUPSUpgradeable, Ownable2StepUpgradeable {

    // Structs
    struct ClaimIdentityParams {
        string name;
        uint256 namespace;
        uint256 stakeAmount;
        address owner;
        string referrer;
    }

    struct SetDataParams {
        string encryptionKey;
        string signatureKey;
        bool routing;
        string[] addressOrProxyNodes;
    }

    struct Delegation {
        string delegatee;
        uint256 amount;
    }

    struct IdentityData {
        uint256 boundNft;
        uint256 stakedTokens;
        string encryptionKey;
        string signatureKey;
        bool routing;
        string[] addressOrProxyNodes;
        uint256 delegatedTokens;
        uint256 lastUpdated;
    }

    struct RewardsState {
        uint224 index;
        uint32 block;
    }

    // State variables
    HanzoTokenInterface public shinToken; // AI token
    HanzoNftInterface public hanzoNft;

    mapping(uint256 => string) public namespaces;
    mapping(string => mapping(string => string)) public identityRecords;
    mapping(string => address) private _identityToOwner;
    mapping(uint256 => string) public tokenIdToIdentity;
    mapping(string => IdentityData) private _identityData;

    // Staking and rewards
    mapping(string => uint256) public identityStakingIndex;
    mapping(string => uint256) public identityDelegationIndex;
    mapping(string => uint256) public identityDelegationAccrued;
    mapping(string => mapping(string => uint256)) public identityDelegations;
    mapping(string => string[]) private _identityDelegatees;

    uint256 public baseRewardsRate;
    uint256 public constant baseRewardsRateMaxMantissa = 1e18;
    RewardsState public rewardsState;

    // Events
    event IdentityClaim(string indexed identity, uint256 nftTokenId, string identityRaw, address owner);
    event IdentityUnclaim(string indexed identity, uint256 nftTokenId);
    event KeysUpdate(string indexed identity, string encryptionKey, string signatureKey);
    event AddressOrProxyNodesUpdate(string indexed identity, bool routing, string[] addressOrProxyNodes);
    event StakeUpdate(string indexed identity, uint256 newStake);
    event DelegationsUpdate(string indexed identity, Delegation[] delegations);
    event DelegatedTokensUpdate(string indexed identity, uint256 newDelegatedTokens);
    event RecordsUpdate(string indexed identity, string[] keys, string[] values);
    event RecordsRemoval(string indexed identity, string[] keys);
    event StakingRewardsClaim(string indexed identity, uint256 rewards);
    event DelegationRewardsAccrual(string indexed identity, uint256 rewards);
    event DelegationRewardsClaim(string indexed identity, uint256 rewards);
    event BaseRewardsRateUpdate(uint256 newRate);

    // Errors
    error IdentityNotAvailable(string identity);
    error InvalidName(string name);
    error InvalidNamespace(uint256 namespace);
    error InvalidReferrer(string referrer);
    error InsufficientStakeAmountForIdentity();
    error InsufficientStakeAmountForDelegation();
    error InvalidDelegationAmount(uint256 amount);
    error DelegatedTokensExceedingStakedTokens(uint256 delegatedTokens, uint256 stakedTokens);
    error Unauthorized();
    error InputArityMismatch();
    error InvalidBaseRewardsRate(uint256 rate);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address owner_,
        address shinToken_,
        address hanzoNft_
    ) public initializer {
        __Ownable_init(owner_);
        __Ownable2Step_init();
        __UUPSUpgradeable_init();

        shinToken = HanzoTokenInterface(shinToken_);
        hanzoNft = HanzoNftInterface(hanzoNft_);

        // Initialize namespaces for all networks
        namespaces[36963] = "hanzo";           // Hanzo mainnet
        namespaces[36962] = "hanzo-testnet";   // Hanzo testnet
        namespaces[96369] = "lux";             // Lux mainnet
        namespaces[96368] = "lux-testnet";     // Lux testnet
        namespaces[200200] = "zoo";            // Zoo mainnet
        namespaces[200201] = "zoo-testnet";    // Zoo testnet
        namespaces[11155111] = "sepolia";      // Sepolia testnet
        namespaces[421614] = "arbitrum-sepolia"; // Arbitrum Sepolia

        baseRewardsRate = 1e16; // 1% base rate
        rewardsState = RewardsState(1e36, uint32(block.number));
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    /**
     * @dev Claim a new identity
     */
    function claimIdentity(ClaimIdentityParams calldata params) external {
        _claimIdentity(params, msg.sender);
    }

    /**
     * @dev Claim identity and set data in one transaction
     */
    function claimIdentityAndSetData(
        ClaimIdentityParams calldata params,
        SetDataParams calldata setDataParams,
        Delegation[] calldata delegations
    ) external {
        string memory identity = _claimIdentity(params, msg.sender);
        _setData(identity, setDataParams);
        if (delegations.length > 0) {
            _setDelegations(identity, delegations);
        }
    }

    /**
     * @dev Claim multiple identities in batch
     */
    function claimIdentityBatched(ClaimIdentityParams[] calldata params) external {
        for (uint256 i = 0; i < params.length; i++) {
            _claimIdentity(params[i], msg.sender);
        }
    }

    function _claimIdentity(ClaimIdentityParams calldata params, address caller) private returns (string memory) {
        // Validate name
        if (!validName(params.name)) revert InvalidName(params.name);

        // Validate namespace
        if (bytes(namespaces[params.namespace]).length == 0) revert InvalidNamespace(params.namespace);

        // Construct identity string: @name.namespace
        string memory identity = string(abi.encodePacked("@", params.name, ".", namespaces[params.namespace]));

        // Check availability
        if (_identityToOwner[identity] != address(0)) revert IdentityNotAvailable(identity);

        // Check stake requirement
        bool validReferrer = bytes(params.referrer).length > 0 && _identityToOwner[params.referrer] != address(0);
        uint256 requiredStake = identityStakeRequirement(params.name, params.namespace, validReferrer);
        if (params.stakeAmount < requiredStake) revert InsufficientStakeAmountForIdentity();

        // Transfer stake
        shinToken.transferFrom(caller, address(this), params.stakeAmount);

        // Mint NFT
        uint256 tokenId = hanzoNft.mint(params.owner);

        // Store identity data
        _identityToOwner[identity] = params.owner;
        tokenIdToIdentity[tokenId] = identity;
        _identityData[identity] = IdentityData({
            boundNft: tokenId,
            stakedTokens: params.stakeAmount,
            encryptionKey: "",
            signatureKey: "",
            routing: false,
            addressOrProxyNodes: new string[](0),
            delegatedTokens: 0,
            lastUpdated: block.timestamp
        });

        emit IdentityClaim(identity, tokenId, identity, params.owner);
        emit StakeUpdate(identity, params.stakeAmount);

        return identity;
    }

    /**
     * @dev Calculate stake requirement for an identity
     *
     * Pricing tiers based on name length:
     * - 1 char: 10,000 AI tokens
     * - 2 chars: 5,000 AI tokens
     * - 3 chars: 1,000 AI tokens
     * - 4+ chars: 100 AI tokens
     *
     * With valid referrer: 50% discount
     */
    function identityStakeRequirement(
        string calldata name,
        uint256 namespace,
        bool validReferrer
    ) public pure returns (uint256) {
        uint256 length = bytes(name).length;
        uint256 baseStake;

        if (length == 1) {
            baseStake = 10000 * 1e18;
        } else if (length == 2) {
            baseStake = 5000 * 1e18;
        } else if (length == 3) {
            baseStake = 1000 * 1e18;
        } else {
            baseStake = 100 * 1e18;
        }

        return validReferrer ? baseStake / 2 : baseStake;
    }

    /**
     * @dev Set identity data (keys and routing)
     */
    function setData(string calldata identity, SetDataParams calldata params) external {
        _requireOwner(identity);
        _setData(identity, params);
    }

    function _setData(string memory identity, SetDataParams calldata params) private {
        IdentityData storage data = _identityData[identity];
        data.encryptionKey = params.encryptionKey;
        data.signatureKey = params.signatureKey;
        data.routing = params.routing;
        data.addressOrProxyNodes = params.addressOrProxyNodes;
        data.lastUpdated = block.timestamp;

        emit KeysUpdate(identity, params.encryptionKey, params.signatureKey);
        emit AddressOrProxyNodesUpdate(identity, params.routing, params.addressOrProxyNodes);
    }

    /**
     * @dev Set multiple identity data in batch
     */
    function setDataBatched(
        string[] calldata identities,
        SetDataParams[] calldata setDataParams
    ) external {
        if (identities.length != setDataParams.length) revert InputArityMismatch();

        for (uint256 i = 0; i < identities.length; i++) {
            _requireOwner(identities[i]);
            _setData(identities[i], setDataParams[i]);
        }
    }

    /**
     * @dev Set encryption and signature keys
     */
    function setKeys(
        string calldata identity,
        string calldata encryptionKey,
        string calldata signatureKey
    ) external {
        _requireOwner(identity);

        IdentityData storage data = _identityData[identity];
        data.encryptionKey = encryptionKey;
        data.signatureKey = signatureKey;
        data.lastUpdated = block.timestamp;

        emit KeysUpdate(identity, encryptionKey, signatureKey);
    }

    /**
     * @dev Set node address
     */
    function setNodeAddress(
        string calldata identity,
        string calldata nodeAddress
    ) external {
        _requireOwner(identity);

        string[] memory nodes = new string[](1);
        nodes[0] = nodeAddress;

        IdentityData storage data = _identityData[identity];
        data.routing = true;
        data.addressOrProxyNodes = nodes;
        data.lastUpdated = block.timestamp;

        emit AddressOrProxyNodesUpdate(identity, true, nodes);
    }

    /**
     * @dev Set proxy nodes
     */
    function setProxyNodes(
        string calldata identity,
        string[] calldata proxyNodes
    ) external {
        _requireOwner(identity);

        IdentityData storage data = _identityData[identity];
        data.routing = false;
        data.addressOrProxyNodes = proxyNodes;
        data.lastUpdated = block.timestamp;

        emit AddressOrProxyNodesUpdate(identity, false, proxyNodes);
    }

    /**
     * @dev Increase stake for an identity
     */
    function increaseStake(string calldata identity, uint256 amount) external {
        _requireOwner(identity);

        shinToken.transferFrom(msg.sender, address(this), amount);

        IdentityData storage data = _identityData[identity];
        data.stakedTokens += amount;
        data.lastUpdated = block.timestamp;

        emit StakeUpdate(identity, data.stakedTokens);
    }

    /**
     * @dev Decrease stake for an identity
     */
    function decreaseStake(
        string calldata name,
        uint256 namespace,
        uint256 amount
    ) external {
        string memory identity = getIdentity(name, namespace);
        _requireOwner(identity);

        IdentityData storage data = _identityData[identity];
        if (data.stakedTokens < amount) revert InsufficientStakeAmountForIdentity();

        data.stakedTokens -= amount;
        data.lastUpdated = block.timestamp;

        shinToken.transfer(msg.sender, amount);

        emit StakeUpdate(identity, data.stakedTokens);
    }

    /**
     * @dev Set delegations for an identity
     */
    function setDelegations(
        string calldata identity,
        Delegation[] calldata delegations
    ) external {
        _requireOwner(identity);
        _setDelegations(identity, delegations);
    }

    function _setDelegations(string memory identity, Delegation[] calldata delegations) private {
        IdentityData storage data = _identityData[identity];

        // Clear existing delegations
        string[] storage delegatees = _identityDelegatees[identity];
        for (uint256 i = 0; i < delegatees.length; i++) {
            delete identityDelegations[identity][delegatees[i]];
        }
        delete _identityDelegatees[identity];

        // Set new delegations
        uint256 totalDelegated = 0;
        for (uint256 i = 0; i < delegations.length; i++) {
            if (delegations[i].amount == 0) revert InvalidDelegationAmount(0);

            identityDelegations[identity][delegations[i].delegatee] = delegations[i].amount;
            _identityDelegatees[identity].push(delegations[i].delegatee);
            totalDelegated += delegations[i].amount;
        }

        if (totalDelegated > data.stakedTokens) {
            revert DelegatedTokensExceedingStakedTokens(totalDelegated, data.stakedTokens);
        }

        data.delegatedTokens = totalDelegated;
        data.lastUpdated = block.timestamp;

        emit DelegationsUpdate(identity, delegations);
        emit DelegatedTokensUpdate(identity, totalDelegated);
    }

    /**
     * @dev Unclaim an identity (burn)
     */
    function unclaimIdentity(string calldata identity) external {
        _requireOwner(identity);

        IdentityData storage data = _identityData[identity];
        uint256 tokenId = data.boundNft;

        // Return staked tokens
        if (data.stakedTokens > 0) {
            shinToken.transfer(msg.sender, data.stakedTokens);
        }

        // Burn NFT
        hanzoNft.burn(tokenId);

        // Clear data
        delete _identityToOwner[identity];
        delete tokenIdToIdentity[tokenId];
        delete _identityData[identity];
        delete _identityDelegatees[identity];

        emit IdentityUnclaim(identity, tokenId);
    }

    /**
     * @dev Unclaim multiple identities in batch
     */
    function unclaimIdentityBatched(string[] calldata identities) external {
        for (uint256 i = 0; i < identities.length; i++) {
            _requireOwner(identities[i]);
            // Implementation would repeat unclaim logic
        }
    }

    /**
     * @dev Update custom records for an identity
     */
    function updateRecords(
        string calldata identity,
        string[] calldata keys,
        string[] calldata values
    ) external {
        _requireOwner(identity);
        if (keys.length != values.length) revert InputArityMismatch();

        for (uint256 i = 0; i < keys.length; i++) {
            identityRecords[identity][keys[i]] = values[i];
        }

        emit RecordsUpdate(identity, keys, values);
    }

    /**
     * @dev Reset all identity data except ownership
     */
    function resetIdentityData(string calldata identity) external {
        _requireOwner(identity);

        IdentityData storage data = _identityData[identity];
        data.encryptionKey = "";
        data.signatureKey = "";
        data.routing = false;
        delete data.addressOrProxyNodes;
        data.lastUpdated = block.timestamp;

        string[] memory emptyArray = new string[](0);
        emit KeysUpdate(identity, "", "");
        emit AddressOrProxyNodesUpdate(identity, false, emptyArray);
    }

    /**
     * @dev Set namespace for a chain ID
     */
    function setNamespace(uint256 id, string calldata namespace) external onlyOwner {
        namespaces[id] = namespace;
    }

    /**
     * @dev Set base rewards rate
     */
    function setBaseRewardsRate(uint256 rate) external onlyOwner {
        if (rate > baseRewardsRateMaxMantissa) revert InvalidBaseRewardsRate(rate);
        baseRewardsRate = rate;
        emit BaseRewardsRateUpdate(rate);
    }

    // Reward functions (simplified)
    function accruel(string calldata identity) external {}
    function claimRewards(string calldata identity) external returns (uint256) { return 0; }
    function claimRewardsBatched(string[] calldata identities) external returns (uint256) { return 0; }
    function claimStakingRewards(string calldata identity) external returns (uint256) { return 0; }
    function claimStakingRewardsBatched(string[] calldata identities) external returns (uint256) { return 0; }
    function claimDelegationRewards(string calldata identity) external returns (uint256) { return 0; }
    function claimDelegationRewardsBatched(string[] calldata identities) external returns (uint256) { return 0; }

    // View functions
    function ownerOf(string calldata identity) external view returns (address) {
        return _identityToOwner[identity];
    }

    function getIdentity(string calldata name, uint256 namespace) public view returns (string memory) {
        return string(abi.encodePacked("@", name, ".", namespaces[namespace]));
    }

    function getIdentityData(string calldata identity) external view returns (IdentityData memory) {
        return _identityData[identity];
    }

    function getDelegatees(string calldata identity) external view returns (string[] memory) {
        return _identityDelegatees[identity];
    }

    function getAvailableTokensForDelegation(string calldata identity) external view returns (uint256) {
        IdentityData storage data = _identityData[identity];
        return data.stakedTokens - data.delegatedTokens;
    }

    function identityDelegatees(string calldata identity, uint256 index) external view returns (string memory) {
        return _identityDelegatees[identity][index];
    }

    /**
     * @dev Validate identity name
     * Names must be alphanumeric with underscores, 1-63 characters
     */
    function validName(string calldata name) public pure returns (bool) {
        bytes memory b = bytes(name);
        if (b.length == 0 || b.length > 63) return false;

        for (uint256 i = 0; i < b.length; i++) {
            bytes1 char = b[i];
            if (!(
                (char >= 0x30 && char <= 0x39) || // 0-9
                (char >= 0x41 && char <= 0x5A) || // A-Z
                (char >= 0x61 && char <= 0x7A) || // a-z
                (char == 0x5F)                     // _
            )) {
                return false;
            }
        }
        return true;
    }

    function _requireOwner(string memory identity) private view {
        if (_identityToOwner[identity] != msg.sender) revert Unauthorized();
    }
}
