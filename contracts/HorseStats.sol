// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/Strings.sol";
import { PerformanceStats } from "./PerformanceStats.sol";

using Strings for uint256;

contract HorseStats {
    string public version = "HorseStats-v1.0.0";

    struct HorseData {
        uint256 color;
        uint256 version;
        PerformanceStats baseStats;
        PerformanceStats assignedStats;
        uint256 totalPoints;
        uint256 unassignedPoints;
        uint256 restFinish;
        uint256 feedFinish;
    }

    address public admin;
    address public racingFixture;
    address public hayToken;
    address public horseMinter;

    mapping(uint256 => HorseData) public horses;
    mapping(uint256 => uint256) public latestVersionPerColor;

    // TODO: definir el costo en HAY token por cada opunto asignado
    uint256 public costPerPoint = 1 ether; // HAY token, asumir 18 decimales

    mapping(uint256 => string) public colorNames;

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
    }

    function createHorse(
        uint256 horseId,
        uint256 color,
        PerformanceStats calldata baseStats
    ) external onlyHorseMinter {
        require(horses[horseId].version == 0, 'Horse already exists');

        uint256 nextVersion = latestVersionPerColor[color] + 1;
        latestVersionPerColor[color] = nextVersion;

        horses[horseId] = HorseData({
            color: color,
            version: nextVersion,
            baseStats: baseStats,
            assignedStats: PerformanceStats(0, 0, 0, 0, 0, 0, 0, 0),
            totalPoints: 0,
            unassignedPoints: 0,
            restFinish: 0,
            feedFinish: 0
        });
    }

    function setRacePrize(uint256 horseId, uint256 points) external onlyRacingFixture {
        require(horses[horseId].version != 0, 'Horse not found');
        horses[horseId].totalPoints += points;
        horses[horseId].unassignedPoints += points;
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
        uint256 raceCooldownStatPoints,
        uint256 feedCooldownStatPoints
    ) external {
        HorseData storage h = horses[horseId];
        require(h.version != 0, 'Horse not found');

        uint256 part1 = _sum5(power, acceleration, stamina, minSpeed, maxSpeed);
        uint256 part2 = _sum5(luck, curveBonus, straightBonus, raceCooldownStatPoints, feedCooldownStatPoints);
        uint256 totalToAssign = part1 + part2;

        require(h.unassignedPoints >= totalToAssign, 'Not enough unassigned points');

        // Cobro en HAY tokens
        require(hayToken != address(0), 'HAY token not set');
        IERC20(hayToken).transferFrom(msg.sender, address(this), totalToAssign * costPerPoint);

        h.assignedStats.power += power;
        h.assignedStats.acceleration += acceleration;
        h.assignedStats.stamina += stamina;
        h.assignedStats.minSpeed += minSpeed;
        h.assignedStats.maxSpeed += maxSpeed;
        h.assignedStats.luck += luck;
        h.assignedStats.curveBonus += curveBonus;
        h.assignedStats.straightBonus += straightBonus;

        // TODO: revisar cuanto tiempo de alimentación debe tener el caballo
        h.feedFinish = block.timestamp + (feedCooldownStatPoints * 1 hours);

        h.unassignedPoints -= totalToAssign;
    }

    // --------------------------------------------------------
    // Getters
    // --------------------------------------------------------


    function hasFinishedResting(uint256 horseId) external view returns (bool) {
        return block.timestamp >= horses[horseId].restFinish;
    }

    function hasFinishedFeeding(uint256 horseId) external view returns (bool) {
        return block.timestamp >= horses[horseId].feedFinish;
    }

    function getAssignedStats(uint256 horseId) external view returns (PerformanceStats memory) {
        return horses[horseId].assignedStats;
    }

    function getBaseStats(uint256 horseId) external view returns (PerformanceStats memory) {
        return horses[horseId].baseStats;
    }

    function getColorVersion(uint256 horseId) external view returns (uint256, uint256) {
        HorseData storage h = horses[horseId];
        return (h.color, h.version);
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
