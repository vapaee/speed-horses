// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title Horse NFT contract
/// @notice Implements horse NFTs with stats and cooldown management
/// @dev All constants used in uppercase are expected to be defined
///      in an external file and imported here.

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import { UD60x18, ud } from "@prb/math/src/UD60x18.sol";

/// @notice Interface for external constants
import "./Constants.sol";

contract Horses is ERC721, ERC721Enumerable, ERC721URIStorage, ReentrancyGuard {
    /// @dev Struct holding performance stats for a horse
    struct PerformanceStats {
        uint256 acceleration;
        uint256 stamina;
        uint256 minSpeed;
        uint256 maxSpeed;
        uint256 luck;
        uint256 curveBonus;
        uint256 straightBonus;
    }

    /// @dev Struct holding cooldown improving stats
    struct CooldownStats {
        uint256 raceCooldownStat;
        uint256 feedCooldownStat;
    }

    // ------------------------------------------------------------------
    // Storage mappings
    // ------------------------------------------------------------------

    /// @notice Stats for each horse id
    mapping(uint256 => PerformanceStats) public performance;
    /// @notice Cooldown improving stats for each horse id
    mapping(uint256 => CooldownStats) public cooldownStats;

    /// @notice timestamp when horse can race again
    mapping(uint256 => uint256) public restFinish;
    /// @notice timestamp when horse can transfer or race again after feeding
    mapping(uint256 => uint256) public feedFinish;

    /// @notice points not yet assigned to stats for each horse
    mapping(uint256 => uint256) public pointsUnassigned;
    /// @notice points already assigned to stats for each horse
    mapping(uint256 => uint256) public pointsAssigned;

    /// @notice address of the race contract allowed to grant rewards
    address public raceContract;
    /// @notice token used to pay for stat assignment
    IERC20 public immutable hayToken;

    /// ------------------------------------------------------------------
    /// Modifiers
    /// ------------------------------------------------------------------

    modifier onlyRaceContract() {
        require(msg.sender == raceContract, "not race contract");
        _;
    }

    modifier onlyWhenNotCoolingForRegistration(uint256 horseId) {
        require(canRegister(horseId), "horse cooling for race");
        _;
    }

    modifier onlyWhenNotCoolingForTransfer(uint256 horseId) {
        require(canTransfer(horseId), "horse cooling for feed");
        _;
    }

    /// ------------------------------------------------------------------
    /// Constructor
    /// ------------------------------------------------------------------

    constructor(address _hayToken) ERC721("Horse", "HORSE") {
        hayToken = IERC20(_hayToken);
    }

    /// ------------------------------------------------------------------
    /// Minting
    /// ------------------------------------------------------------------

    function mint(address to, uint256 tokenId, string memory tokenURI) external {
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, tokenURI);
    }

    /// ------------------------------------------------------------------
    /// Horse advance logic
    /// ------------------------------------------------------------------

    /// @notice Calculate the distance advanced by a horse in one tick
    function advanceHorse(
        uint256 id,
        bytes32 rand,
        bool isRect,
        uint256 length,
        uint256 tick
    ) public view returns (uint256) {
        PerformanceStats memory stats = performance[id];

        // level calculation for each stat
        uint256 minSpeedLevel = levelProp(stats.minSpeed);
        uint256 luckLevel = levelProp(stats.luck);
        uint256 curveLevel = levelProp(stats.curveBonus);
        uint256 straightLevel = levelProp(stats.straightBonus);
        uint256 maxSpeedLevel = levelProp(stats.maxSpeed);
        uint256 staminaLevel = levelProp(stats.stamina);
        uint256 accelerationLevel = levelProp(stats.acceleration);

        uint256 minSpeedBonus = minSpeedLevel * MIN_SPEED_BASE_VALUE;

        // luck bonus
        uint256 randomLuck = uint256(keccak256(abi.encodePacked(rand, LUCK_ENUM)));
        uint256 percentLuck = randomLuck % 100;
        uint256 luckBonus = percentLuck * LUCK_SPEED_PER_LEVEL * (luckLevel + LUCK_MIN_POINTS);

        // curve or straight bonus depending on section
        uint256 curveBonusValue = 0;
        uint256 straightBonusValue = 0;
        if (!isRect) {
            uint256 randomCurve = uint256(
                keccak256(abi.encodePacked(rand, CURVE_ENUM))
            );
            uint256 percentCurve = randomCurve % 100;
            curveBonusValue = percentCurve * CURVE_SPEED_PER_LEVEL * (curveLevel + CURVE_MIN_POINTS);
        } else {
            uint256 randomStraight = uint256(
                keccak256(abi.encodePacked(rand, STRAIGHT_ENUM))
            );
            uint256 percentStraight = randomStraight % 100;
            straightBonusValue = percentStraight * STRAIGHT_SPEED_PER_LEVEL * (straightLevel + STRAIGHT_MIN_POINTS);
        }

        // calculate advance before max speed check
        uint256 calculatedAdvance = minSpeedBonus + luckBonus + curveBonusValue + straightBonusValue;

        // apply max speed cap
        uint256 maxSpeedThreshold = (MAX_SPEED_EXTRA_POINTS + maxSpeedLevel) * MAX_SPEED_ADVANCE_PER_LEVEL;
        if (calculatedAdvance > maxSpeedThreshold) {
            calculatedAdvance = maxSpeedThreshold;
        }

        // stamina effect
        uint256 distancePerTick = length / TOTAL_RACE_ITERATIONS;
        uint256 currentDistance = distancePerTick * tick;
        uint256 extraLength = STAMINA_METERS_PER_LEVEL * staminaLevel;
        uint256 threshold = MIN_DISTANCE_RESISTANCE + extraLength;
        uint256 finalPercent = 100;
        if (threshold < currentDistance) {
            uint256 afterThresholdTicks = (currentDistance - threshold) / distancePerTick;
            if (afterThresholdTicks * 2 >= 20) {
                finalPercent = 80;
            } else {
                uint256 reduction = afterThresholdTicks * 2;
                if (reduction > 20) reduction = 20;
                finalPercent = 100 - reduction;
            }
        }

        calculatedAdvance = (calculatedAdvance * finalPercent) / 100;

        // acceleration effect
        uint256 speedUpRange = TOTAL_ACCELERATION - min(MAX_ACCELERATION, accelerationLevel);
        uint256 percentageGainPerTick = 100 / speedUpRange;
        uint256 finalPercentage = percentageGainPerTick * tick;
        if (finalPercentage > 100) finalPercentage = 100;
        calculatedAdvance = (calculatedAdvance * finalPercentage) / 100;

        return calculatedAdvance;
    }

    /// ------------------------------------------------------------------
    /// Rewards after race
    /// ------------------------------------------------------------------

    /// @notice Called by race contract to award points and set cooldown
    function setRacePrize(
        uint256 id,
        uint256 /*position*/,
        uint256 points
    ) external onlyRaceContract {
        pointsUnassigned[id] += points;

        uint256 restDelay = _inverseRaceCooldown(levelProp(cooldownStats[id].raceCooldownStat));
        if (restFinish[id] >= block.timestamp) {
            restFinish[id] += restDelay;
        } else {
            restFinish[id] = block.timestamp + restDelay;
        }
    }

    /// ------------------------------------------------------------------
    /// Assign points
    /// ------------------------------------------------------------------

    /// @notice Assign unassigned points to performance or cooldown stats
    function assignPoints(
        uint256 horseId,
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
        uint256 totalPoints =
            acceleration +
            stamina +
            minSpeed +
            maxSpeed +
            luck +
            curveBonus +
            straightBonus +
            raceCooldownStatPoints +
            feedCooldownStatPoints;
        require(pointsUnassigned[horseId] >= totalPoints, "not enough points");

        uint256 cost = totalPoints * PRICE_PER_POINT;
        hayToken.transferFrom(msg.sender, address(this), cost);

        pointsUnassigned[horseId] -= totalPoints;
        pointsAssigned[horseId] += totalPoints;

        PerformanceStats storage perf = performance[horseId];
        perf.acceleration += acceleration;
        perf.stamina += stamina;
        perf.minSpeed += minSpeed;
        perf.maxSpeed += maxSpeed;
        perf.luck += luck;
        perf.curveBonus += curveBonus;
        perf.straightBonus += straightBonus;

        cooldownStats[horseId].raceCooldownStat += raceCooldownStatPoints;
        cooldownStats[horseId].feedCooldownStat += feedCooldownStatPoints;

        uint256 feedDelay = _inverseFeedCooldown(levelProp(cooldownStats[horseId].feedCooldownStat));
        if (feedFinish[horseId] >= block.timestamp) {
            feedFinish[horseId] += feedDelay;
        } else {
            feedFinish[horseId] = block.timestamp + feedDelay;
        }
    }

    /// ------------------------------------------------------------------
    /// Cooldown helpers
    /// ------------------------------------------------------------------

    function canRegister(uint256 id) public view returns (bool) {
        return block.timestamp >= restFinish[id] && block.timestamp >= feedFinish[id];
    }

    function canTransfer(uint256 id) public view returns (bool) {
        return block.timestamp >= feedFinish[id];
    }

    /// ------------------------------------------------------------------
    /// Level calculation utilities
    /// ------------------------------------------------------------------

    function level(uint256 horseId) public view returns (uint256) {
        uint256 total = pointsAssigned[horseId] + pointsUnassigned[horseId];
        return floorLog2(total);
    }

    function levelProp(uint256 points) public pure returns (uint256 result) {
        if (points == 0) return 0;
        UD60x18 x = ud(points * 1e18);
        UD60x18 res = x.log2();
        result = res.intoUint256();
    }

    function floorLog2(uint256 x) internal pure returns (uint256) {
        uint256 res;
        while (x > 1) {
            x >>= 1;
            res++;
        }
        return res;
    }

    /// ------------------------------------------------------------------
    /// Internal cooldown calculation
    /// ------------------------------------------------------------------

    function _inverseRaceCooldown(uint256 levelVal) internal pure returns (uint256) {
        return BASE_RACE_COOLDOWN / (levelVal + 1);
    }

    function _inverseFeedCooldown(uint256 levelVal) internal pure returns (uint256) {
        return BASE_FEED_COOLDOWN / (levelVal + 1);
    }

    /// ------------------------------------------------------------------
    /// Overrides to include cooldown checks
    /// ------------------------------------------------------------------

    function _update(
        address from,
        address to,
        uint256 tokenId,
        address auth
    ) internal override(ERC721, ERC721Enumerable, ERC721URIStorage) onlyWhenNotCoolingForTransfer(tokenId) {
        super._update(from, to, tokenId, auth);
    }

    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable, ERC721URIStorage)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    // Helper to get min of two values
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
}

