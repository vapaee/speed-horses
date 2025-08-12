// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/Strings.sol";
import { PerformanceStats, CooldownStats } from './StatsStructs.sol';
import { UFix6, UFix6Lib } from "./UFix6Lib.sol";

using Strings for uint256;
using UFix6Lib for UFix6;

contract HorseStats {
    string public version = "HorseStats-v1.0.0";

    // ---------------------------------------------------------------------
    // Contract References
    // ---------------------------------------------------------------------
    address public admin;
    address public racingFixture;
    address public hayToken;
    address public horseMinter;

    // ---------------------------------------------------------------------
    // Constants
    // ---------------------------------------------------------------------
    uint256 constant BASE_RESTING_COOLDOWN          = 1 days;
    uint256 constant FEEDING_COST_PER_POIONT        = 1 ether; // Cost in HAY tokens to assign 1 point

    // ---------------------------------------------------------------------
    // Structs and Mappings
    // ---------------------------------------------------------------------
    struct HorseData {
        uint256 color;
        uint256 version;
        PerformanceStats baseStats;
        PerformanceStats assignedStats;
        PerformanceStats levelStats; // cached levels for each stat
        CooldownStats coolDownStats;
        uint256 totalPoints;
        uint256 unassignedPoints;
        uint256 restFinish;
    }

    mapping(uint256 => HorseData) public horses;
    mapping(uint256 => uint256) public latestVersionPerColor;
    mapping(uint256 => string) public colorNames;

    // ---------------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------------
    event HorseCreated(uint256 indexed horseId, uint256 color, PerformanceStats baseStats);
    event ColorNameSet(uint256 indexed colorId, string name);
    event HorseStatsUpdated(uint256 indexed horseId, PerformanceStats stats);
    event HorseWonPrize(uint256 indexed horseId, uint256 points);


    modifier onlyAdmin() {
        require(msg.sender == admin, "Not admin");
        _;
    }

    modifier onlyRacingFixture() {
        require(msg.sender == racingFixture, "Not RacingFixture");
        _;
    }

    modifier onlyHorseMinter() {
        require(msg.sender == horseMinter, "Not horseMinter");
        _;
    }

    constructor() {
        admin = msg.sender;
    }

    function setRacingFixture(address _fixture) external onlyAdmin {
        racingFixture = _fixture;
    }

    function setHayToken(address _token) external onlyAdmin {
        hayToken = _token;
    }

    function setHorseMinter(address _minter) external onlyAdmin {
        horseMinter = _minter;
    }

    function setColorName(uint256 colorId, string calldata name) external onlyAdmin {
        colorNames[colorId] = name;
        emit ColorNameSet(colorId, name);
    }

    function createHorse(uint256 horseId, uint256 color, PerformanceStats calldata baseStats) external onlyHorseMinter {
        require(horses[horseId].version == 0, 'Horse already exists');

        uint256 nextVersion = latestVersionPerColor[color] + 1;
        latestVersionPerColor[color] = nextVersion;

        horses[horseId] = HorseData({
            color: color,
            version: nextVersion,
            baseStats: baseStats,
            assignedStats: PerformanceStats(0, 0, 0, 0, 0, 0, 0, 0),
            levelStats: PerformanceStats(0, 0, 0, 0, 0, 0, 0, 0),
            coolDownStats: CooldownStats(0),
            totalPoints: 0,
            unassignedPoints: 0,
            restFinish: 0,
        });

        _setPropertyLevels(horseId);

        emit HorseCreated(horseId, color, baseStats);
    }

    function setRacePrize(uint256 horseId, uint256 points) external onlyRacingFixture {
        require(horses[horseId].version != 0, 'Horse not found');
        horses[horseId].totalPoints += points;
        horses[horseId].unassignedPoints += points;

        _startResting(horseId);

        emit HorseWonPrize(horseId, points);
    }

    function _sum5(
        uint256 a,
        uint256 b,
        uint256 c,
        uint256 d,
        uint256 e
    ) internal pure returns (uint256) {
        return a + b + c + d + e;
    }

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
        uint256 resting
    ) external {
        HorseData storage h = horses[horseId];
        require(h.version != 0, 'Horse not found');

        uint256 part1 = _sum5(power, acceleration, stamina, minSpeed, maxSpeed);
        uint256 part2 = _sum5(luck, curveBonus, straightBonus, resting, 0);
        uint256 totalToAssign = part1 + part2;

        require(h.unassignedPoints >= totalToAssign, 'Not enough unassigned points');

        // Cobro en HAY tokens
        require(hayToken != address(0), 'HAY token not set');
        IERC20(hayToken).transferFrom(msg.sender, address(this), totalToAssign * FEEDING_COST_PER_POIONT);

        h.assignedStats.power += power;
        h.assignedStats.acceleration += acceleration;
        h.assignedStats.stamina += stamina;
        h.assignedStats.minSpeed += minSpeed;
        h.assignedStats.maxSpeed += maxSpeed;
        h.assignedStats.luck += luck;
        h.assignedStats.curveBonus += curveBonus;
        h.assignedStats.straightBonus += straightBonus;

        _setPropertyLevels(horseId);

        h.coolDownStats.resting += resting;

        h.unassignedPoints -= totalToAssign;
        h.totalPoints += totalToAssign;

        emit HorseStatsUpdated(horseId, h.assignedStats);
    }

    function _setPropertyLevels(uint256 horseId) public {
        HorseData storage h = horses[horseId];
        require(h.version != 0, 'Horse not found');
        h.levelStats.power         = getPower(horseId);
        h.levelStats.acceleration  = getAcceleration(horseId);
        h.levelStats.stamina       = getStamina(horseId);
        h.levelStats.minSpeed      = getMinSpeed(horseId);
        h.levelStats.maxSpeed      = getMaxSpeed(horseId);
        h.levelStats.luck          = getLuck(horseId);
        h.levelStats.curveBonus    = getCurveBonus(horseId);
        h.levelStats.straightBonus = getStraightBonus(horseId);
    }

    function _startResting(uint256 horseId) public {
        HorseData storage h = horses[horseId];
        require(h.version != 0, 'Horse not found');
        uint256 lv = getRestingCoolDown(horseId);
        uint256 delay = BASE_RESTING_COOLDOWN / (lv + 1);
        if (h.restFinish >= block.timestamp) {
            h.restFinish += delay;
        } else {
            h.restFinish = block.timestamp + delay;
        }
    }

    // --------------------------------------------------------
    // Getters
    // --------------------------------------------------------

    function hasFinishedResting(uint256 horseId) public view returns (bool) {
        return block.timestamp >= horses[horseId].restFinish;
    }

    function getAssignedStats(uint256 horseId) public view returns (PerformanceStats memory) {
        return horses[horseId].assignedStats;
    }

    function getBaseStats(uint256 horseId) public view returns (PerformanceStats memory) {
        return horses[horseId].baseStats;
    }

    function getColorVersion(uint256 horseId) public view returns (uint256, uint256) {
        HorseData memory h = horses[horseId];
        return (h.color, h.version);
    }

    function getTotalPoints(uint256 horseId) public view returns (uint256) {
        HorseData storage h = horses[horseId];
        require(h.version != 0, 'Horse not found');
        return horses[horseId].totalPoints;
    }

    function getUnassignedPoints(uint256 horseId) public view returns (uint256) {
        HorseData memory h = horses[horseId];
        require(h.version != 0, 'Horse not found');
        return h.unassignedPoints;
    }

    function getLevel(uint256 horseId) public view returns (uint256 level) {
        HorseData memory h = horses[horseId];
        require(h.version != 0, 'Horse not found');
        // level = floor(h.levelStats.power * h.totalPoints / log2(h.totalPoints));
        UFix6 power = UFix6.wrap(h.levelStats.power);
        UFix6 totalPoints = UFix6Lib.fromUint(h.totalPoints);
        UFix6 logTotal = UFix6Lib.log2_uint(h.totalPoints);
        UFix6 result = UFix6Lib.div(UFix6Lib.mul(power, totalPoints), logTotal);
        level = UFix6Lib.toUint(result);
    }

    function getPower(uint256 horseId) public view returns (uint256 power) {
        HorseData memory h = horses[horseId];
        require(h.version != 0, 'Horse not found');
        uint256 value = h.assignedStats.power + h.baseStats.power;
        // power = 1 + log2(value) * 0.1;
        UFix6 logValue = UFix6Lib.log2_uint(value);
        UFix6 scaled = UFix6Lib.mul(logValue, UFix6.wrap(100000));
        UFix6 result = UFix6Lib.add(UFix6Lib.one(), scaled);
        power = UFix6.unwrap(result);
    }

    function getAcceleration(uint256 horseId) public view returns (uint256 acceleration) {
        HorseData memory h = horses[horseId];
        require(h.version != 0, 'Horse not found');
        uint256 value = h.baseStats.acceleration + h.assignedStats.acceleration;
        acceleration = _computePerformanceStat(h.levelStats.power, value);
    }

    function getStamina(uint256 horseId) public view returns (uint256 stamina) {
        HorseData memory h = horses[horseId];
        require(h.version != 0, 'Horse not found');
        uint256 value = h.baseStats.stamina + h.assignedStats.stamina;
        stamina = _computePerformanceStat(h.levelStats.power, value);
    }

    function getMinSpeed(uint256 horseId) public view returns (uint256 minSpeed) {
        HorseData memory h = horses[horseId];
        require(h.version != 0, 'Horse not found');
        uint256 value = h.baseStats.minSpeed + h.assignedStats.minSpeed;
        minSpeed = _computePerformanceStat(h.levelStats.power, value);
    }

    function getMaxSpeed(uint256 horseId) public view returns (uint256 maxSpeed) {
        HorseData memory h = horses[horseId];
        require(h.version != 0, 'Horse not found');
        uint256 value = h.baseStats.maxSpeed + h.assignedStats.maxSpeed;
        maxSpeed = _computePerformanceStat(h.levelStats.power, value);
    }

    function getLuck(uint256 horseId) public view returns (uint256 luck) {
        HorseData memory h = horses[horseId];
        require(h.version != 0, 'Horse not found');
        uint256 value = h.baseStats.luck + h.assignedStats.luck;
        luck = _computePerformanceStat(h.levelStats.power, value);
    }

    function getCurveBonus(uint256 horseId) public view returns (uint256 curveBonus) {
        HorseData memory h = horses[horseId];
        require(h.version != 0, 'Horse not found');
        uint256 value = h.baseStats.curveBonus + h.assignedStats.curveBonus;
        curveBonus = _computePerformanceStat(h.levelStats.power, value);
    }

    function getStraightBonus(uint256 horseId) public view returns (uint256 straightBonus) {
        HorseData memory h = horses[horseId];
        require(h.version != 0, 'Horse not found');
        uint256 value = h.baseStats.straightBonus + h.assignedStats.straightBonus;
        straightBonus = _computePerformanceStat(h.levelStats.power, value);
    }

    function getRestingCoolDown(uint256 horseId) public view returns (uint256 resting) {
        HorseData memory h = horses[horseId];
        require(h.version != 0, 'Horse not found');
        uint256 value = h.coolDownStats.resting;
        resting = _computeCooldownStat(h.levelStats.power, value);
    }

    function _computePerformanceStat(uint256 powerLevel, uint256 value) internal pure returns (uint256) {
        // result = powerLevel * value / log2(value)
        UFix6 power = UFix6.wrap(powerLevel);
        UFix6 val = UFix6Lib.fromUint(value);
        UFix6 logValue = UFix6Lib.log2_uint(value);
        UFix6 result = UFix6Lib.div(UFix6Lib.mul(power, val), logValue);
        return UFix6.unwrap(result);
    }

    function _computeCooldownStat(uint256 value) internal pure returns (uint256) {
        // TODO: Implementar lógica de reducción de cooldown usando UFix6
        // result = BASE_RESTING_COOLDOWN * 16/(value + 15)
        return UFix6.unwrap(result);
    }

    // --------------------------------------------------------
    // tokenURI returns directly an updated JSON string
    // --------------------------------------------------------
    function tokenURI(uint256 id) external view virtual returns (string memory) {
        HorseData storage h = horses[id];
        require(h.version != 0, "Horse not found");

        string memory mainBodyStr = _buildMainBody(id, h);
        string memory attributesStr = _buildAttributes(h);

        string memory json = string.concat(
            '{',
            mainBodyStr,
            '"attributes": [', attributesStr, ']',
            '}'
        );

        return json;
    }

    function _getColorString(uint256 color) internal view returns (string memory) {
        string memory name = colorNames[color];
        if (bytes(name).length == 0) {
            return string.concat("color-", Strings.toString(color)); // fallback si no está definido
        }
        return name;
    }

    function _buildMainBody(uint256 id, HorseData storage h) internal view returns (string memory) {
        string memory idStr = id.toString();
        string memory versionStr = h.version.toString();
        string memory colorStr = _getColorString(h.color);

        return string.concat(
            '"id": ', idStr, ',',
            '"name": "Horse #', idStr, '",',
            '"description": "Description here",',
            '"imageUrl": "https://tekika-nfts.s3.amazonaws.com/tokens/', colorStr, '-', versionStr, '.webp",'
        );
    }

    function _buildAttributes(HorseData storage h) internal view returns (string memory) {

        string memory colorStr = _getColorString(h.color);
        string memory powerStr = h.baseStats.power.toString();
        string memory accelerationStr = h.baseStats.acceleration.toString();
        string memory staminaStr = h.baseStats.stamina.toString();
        string memory minSpeedStr = h.baseStats.minSpeed.toString();
        string memory maxSpeedStr = h.baseStats.maxSpeed.toString();
        string memory luckStr = h.baseStats.luck.toString();
        string memory curveBonusStr = h.baseStats.curveBonus.toString();
        string memory straightBonusStr = h.baseStats.straightBonus.toString();

        return string.concat(
            '{"trait_type": "color", "value": "', colorStr, '"},',
            '{"trait_type": "power", "value": ', powerStr, '},',
            '{"trait_type": "acceleration", "value": ', accelerationStr, '},',
            '{"trait_type": "stamina", "value": ', staminaStr, '},',
            '{"trait_type": "minSpeed", "value": ', minSpeedStr, '},',
            '{"trait_type": "maxSpeed", "value": ', maxSpeedStr, '},',
            '{"trait_type": "luck", "value": ', luckStr, '},',
            '{"trait_type": "curveBonus", "value": ', curveBonusStr, '},',
            '{"trait_type": "straightBonus", "value": ', straightBonusStr, '}'
        );
    }
}

interface IERC20 {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}
