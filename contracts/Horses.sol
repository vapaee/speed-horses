// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import { UD60x18, ud } from '@prb/math/src/UD60x18.sol';
import './Constants.sol';

contract Horses is
    ERC721,
    ERC721Enumerable,
    ERC721URIStorage,
    ReentrancyGuard
{
    // --------------------------------------------------
    // Data structures and storage
    // --------------------------------------------------

    /// @notice Performance attributes for each horse
    struct PerformanceStats {
        uint256 power;
        uint256 acceleration;
        uint256 stamina;
        uint256 minSpeed;
        uint256 maxSpeed;
        uint256 luck;
        uint256 curveBonus;
        uint256 straightBonus;
    }

    /// @notice Cooldown reduction attributes for each horse
    struct CooldownStats {
        uint256 raceCooldownStat;
        uint256 feedCooldownStat;
    }

    mapping(uint256 => PerformanceStats) public performance;
    mapping(uint256 => CooldownStats)  public cooldownStats;
    mapping(uint256 => uint256)        public restFinish;
    mapping(uint256 => uint256)        public feedFinish;
    mapping(uint256 => uint256)        public pointsUnassigned;
    mapping(uint256 => uint256)        public pointsAssigned;

    address public raceContract;
    IERC20 public immutable hayToken;

    // --------------------------------------------------
    // Modifiers
    // --------------------------------------------------

    /// @notice Restricts calls to the configured race contract
    modifier onlyRaceContract() {
        require(msg.sender == raceContract, 'not race contract');
        _;
    }

    /// @notice Ensures a horse is not cooling before transfer
    modifier onlyWhenNotCoolingForTransfer(uint256 horseId) {
        require(canTransfer(horseId), 'horse cooling for feed');
        _;
    }

    // --------------------------------------------------
    // Constructor and configuration
    // --------------------------------------------------

    /// @notice Initializes the NFT and sets the HAY token address
    constructor(address _hayToken) ERC721('Horse', 'HORSE') {
        hayToken = IERC20(_hayToken);
    }

    /// @notice Sets the race contract that is allowed to award points
    function setRaceContract(address _raceContract) external {
        raceContract = _raceContract;
    }

    // --------------------------------------------------
    // Minting
    // --------------------------------------------------

    /// @notice Mints a new horse NFT and sets its metadata URI
    function mint(
        address to,
        uint256 tokenId,
        string memory uri
    ) external {
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);

        // TODO: sacar esto de acá
        performance[tokenId] = PerformanceStats(tokenId, tokenId, tokenId, tokenId, tokenId, tokenId, tokenId);
    }

    // --------------------------------------------------
    // External and public logic
    // --------------------------------------------------

    /// @notice Calculates the distance advanced by a horse in one tick
    function advanceHorse(
        uint256 id,
        bytes32 rand,
        bool isRect,
        uint256 length,
        uint256 tick
    ) public view returns (uint256) {
        PerformanceStats memory s = performance[id];

        uint256 base = computeBase(id, rand);
        uint256 luck = computeLuck(id, rand);

        uint256 section = computeSection(id, rand, isRect);

        uint256 advance = base + luck + section;
        uint256 cap     = (MAX_SPEED_EXTRA_POINTS + levelProp(s.maxSpeed)) * MAX_SPEED_ADVANCE_PER_LEVEL;
        if (advance > cap) {
            advance = cap;
        }

        advance = _applyStamina(advance, length, tick, levelProp(s.stamina));
        advance = _applyAcceleration(advance, tick, levelProp(s.acceleration));

        return advance;
    }

    function computeBase(
        uint256 id,
        bytes32 rand
    ) public view returns (uint256 base) {
        PerformanceStats memory s = performance[id];
        uint256 lvl = levelProp(s.minSpeed + 2);
        uint256 luckR = uint256(keccak256(abi.encodePacked(rand, id, "base"))) % 30;
        base = lvl * (luckR + 50);
    }

    function computeLuck(
        uint256 id,
        bytes32 rand
    ) public view returns (uint256 luck) {
        PerformanceStats memory s = performance[id];
        uint256 luckR = uint256(keccak256(abi.encodePacked(rand, id, "luck"))) % 160;
        luck = luckR * levelProp(s.luck + 1);
        return luck;
    }

    /// @dev Computes bonus for curve or straight section
    function computeSection(
        uint256 id,
        bytes32 rand,
        bool isRect
    ) public view returns (uint256) {
        PerformanceStats memory s = performance[id];
        if (!isRect) {
            uint256 lvl = levelProp(s.curveBonus);
            uint256 r = uint256(keccak256(abi.encodePacked(rand, id, "curve"))) % 100;
            return r * lvl;
        } else {
            uint256 lvl = levelProp(s.straightBonus);
            uint256 r = uint256(keccak256(abi.encodePacked(rand, id, "straight"))) % 100;
            return r * lvl;
        }
    }

    /// @notice Awards unassigned points after a race and sets race cooldown
    function setRacePrize(
        uint256 id,
        uint256 /*pos*/,
        uint256 pts
    ) external onlyRaceContract {
        pointsUnassigned[id] += pts;
        uint256 delay = _inverseRaceCooldown(levelProp(cooldownStats[id].raceCooldownStat));
        if (restFinish[id] >= block.timestamp) {
            restFinish[id] += delay;
        } else {
            restFinish[id] = block.timestamp + delay;
        }
    }

    /// @notice Assigns earned points to performance and cooldown stats
    function assignPoints(
        uint256 horseId,
        uint256 power,
        uint256 acceleration,
        uint256 stamina,
        uint256 minSpeed,
        uint256 maxSpeed,
        uint256 luck,
        uint256 curveBonus,
        uint256 straightBonus,
        uint256 raceCooldownStatPoints,
        uint256 feedCooldownStatPoints
    ) external nonReentrant {
        // 1) Sum and validate total points
        uint256 total = _sumPoints(
            acceleration,
            stamina,
            minSpeed,
            maxSpeed,
            luck,
            curveBonus,
            straightBonus,
            raceCooldownStatPoints,
            feedCooldownStatPoints
        );
        require(pointsUnassigned[horseId] >= total, 'not enough points');

        // 2) Transfer HAY token cost and update counters
        uint256 cost = total * PRICE_PER_POINT;
        hayToken.transferFrom(msg.sender, address(this), cost);
        pointsUnassigned[horseId] -= total;
        pointsAssigned[horseId]   += total;

        // 3) Update performance stats
        _applyPerformance(
            horseId,
            acceleration,
            stamina,
            minSpeed,
            maxSpeed,
            luck,
            curveBonus,
            straightBonus
        );

        // 4) Update cooldown stats and feed finish timestamp
        _applyCooldown(
            horseId,
            raceCooldownStatPoints,
            feedCooldownStatPoints
        );
    }

    /// @notice Checks if a horse can enter a race
    function canRegister(uint256 id) public view returns (bool) {
        return block.timestamp >= restFinish[id] && block.timestamp >= feedFinish[id];
    }

    /// @notice Checks if a horse can be transferred (not feeding)
    function canTransfer(uint256 id) public view returns (bool) {
        return block.timestamp >= feedFinish[id];
    }

    /// @notice Computes the overall level based on assigned + unassigned points
    function level(uint256 horseId) public view returns (uint256) {
        uint256 tot = pointsAssigned[horseId] + pointsUnassigned[horseId];
        return floorLog2(tot);
    }

    /// @notice Computes the level of a single stat using log2
    function levelProp(uint256 pts) public pure returns (uint256) {
        if (pts == 0) return 0;
        if (pts == 1) return 5e17;
        UD60x18 x = ud(pts * 1e18);
        return x.log2().intoUint256();
    }

    /// @dev Helper to compute floor(log2(x))
    function floorLog2(uint256 x) internal pure returns (uint256 r) {
        while (x > 1) {
            x >>= 1;
            r++;
        }
    }

    // --------------------------------------------------
    // Internal helper functions
    // --------------------------------------------------

    /// @dev Applies stamina reduction effect to the advance value
    function _applyStamina(
        uint256 advance,
        uint256 length,
        uint256 tick,
        uint256 staminaLevel
    ) internal pure returns (uint256) {
        // TODO: perTick debería ser fijo (25 metros por tick)
        uint256 perTick   = length / TOTAL_RACE_ITERATIONS;
        uint256 currDist  = perTick * tick;
        uint256 threshold = MIN_DISTANCE_RESISTANCE + STAMINA_METERS_PER_LEVEL * staminaLevel;
        // threshold representa el punto a partir del cual la resistencia comienza a afectar
        if (currDist <= threshold) {
            // Si no llega a ese punto, no hay reducción
            return advance;
        }
        // _after representa la cantidad de ticks que superan el threshold
        uint256 _after        = (currDist - threshold) / perTick;
        // TODO: el multiplicador 2 debería ser una constante configurable
        uint256 reductionPct  = _after * 2;
        // La reducción máxima es del 20% (2 * 10%)
        if (reductionPct > 20) reductionPct = 20;
        uint256 pct = 100 - reductionPct;
        // TODO: averiguar si no hay pérdida de precisión al dividir por 100
        return (advance * pct) / 100;

    }

    /// @dev Applies acceleration ramp-up effect to the advance value
    function _applyAcceleration(
        uint256 advance,
        uint256 tick,
        uint256 accelLevel
    ) internal pure returns (uint256) {
        uint256 range = TOTAL_ACCELERATION - min(MAX_ACCELERATION, accelLevel);
        uint256 gain  = 100 / range;
        uint256 pct   = gain * tick;
        if (pct > 100) pct = 100;
        return (advance * pct) / 100;
    }

    /// @dev Sums nine point allocations
    function _sumPoints(
        uint256 a,
        uint256 b,
        uint256 c,
        uint256 d,
        uint256 e,
        uint256 f,
        uint256 g,
        uint256 h,
        uint256 i
    ) internal pure returns (uint256) {
        return _sum5(a, b, c, d, e) + _sum5(f, g, h, i, 0);
    }

    /// @dev Sums five values
    function _sum5(
        uint256 a,
        uint256 b,
        uint256 c,
        uint256 d,
        uint256 e
    ) internal pure returns (uint256) {
        return a + b + c + d + e;
    }

    /// @dev Updates performance stats in storage
    function _applyPerformance(
        uint256 horseId,
        uint256 acceleration,
        uint256 stamina,
        uint256 minSpeed,
        uint256 maxSpeed,
        uint256 luck,
        uint256 curveBonus,
        uint256 straightBonus
    ) internal {
        PerformanceStats storage ps = performance[horseId];
        ps.acceleration  += acceleration;
        ps.stamina       += stamina;
        ps.minSpeed      += minSpeed;
        ps.maxSpeed      += maxSpeed;
        ps.luck          += luck;
        ps.curveBonus    += curveBonus;
        ps.straightBonus += straightBonus;
    }

    /// @dev Updates cooldown stats and adjusts feedFinish timestamp
    function _applyCooldown(
        uint256 horseId,
        uint256 racePoints,
        uint256 feedPoints
    ) internal {
        CooldownStats storage cs = cooldownStats[horseId];
        cs.raceCooldownStat += racePoints;
        cs.feedCooldownStat += feedPoints;

        uint256 delay = _inverseFeedCooldown(levelProp(cs.feedCooldownStat));
        if (feedFinish[horseId] >= block.timestamp) {
            feedFinish[horseId] += delay;
        } else {
            feedFinish[horseId] = block.timestamp + delay;
        }
    }

    /// @dev Calculates inverse race cooldown based on level
    function _inverseRaceCooldown(uint256 lv) internal pure returns (uint256) {
        return BASE_RACE_COOLDOWN / (lv + 1);
    }

    /// @dev Calculates inverse feed cooldown based on level
    function _inverseFeedCooldown(uint256 lv) internal pure returns (uint256) {
        return BASE_FEED_COOLDOWN / (lv + 1);
    }

    /// @dev Returns the minimum of two values
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    // --------------------------------------------------
    // Overrides for cooldown enforcement and multiple inheritance
    // --------------------------------------------------

    /// @notice Overrides transfer logic to enforce feed cooldown
    function _update(
        address to,
        uint256 tokenId,
        address auth
    )
        internal
        override(ERC721, ERC721Enumerable)
        onlyWhenNotCoolingForTransfer(tokenId)
        returns (address)
    {
        return super._update(to, tokenId, auth);
    }

    /// @notice Resolves balance tracking conflict between ERC721 and Enumerable
    function _increaseBalance(address account, uint128 value)
        internal
        override(ERC721, ERC721Enumerable)
    {
        super._increaseBalance(account, value);
    }

    /// @notice Resolves metadata URI conflict between ERC721 and URIStorage
    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    /// @notice Resolves multiple supportsInterface implementations
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable, ERC721URIStorage)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}

