// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/Strings.sol";
import { PerformanceStats, CooldownStats } from './StatsStructs.sol';
import { UFix6, UFix6Lib } from "./UFix6Lib.sol";

using Strings for uint256;
using UFix6Lib for UFix6;

/**
 * Título: HorseStats
 * Brief: Registro centralizado de atributos y progresión de cada caballo, encargado de almacenar categorías y números de imagen, contabilizar puntos ganados, aplicar tiempos de descanso y generar el JSON dinámico utilizado por los NFTs. Provee la lógica para calcular niveles y bonificaciones basadas en estadísticas base, asignadas y niveles derivados, además de coordinar con otros módulos como el fixture y el token de recompensas.
 * API: incluye métodos administrativos para vincular contratos (`setFixtureManager`, `setHayToken`, `setHorseMinter`, `setImgCategory`), creación inicial desde el minter (`createHorse`) y actualización post-carrera (`setRacePrize`). Los jugadores interactúan mediante `assignPoints` para redistribuir puntos tras pagar en HAY, mientras que una amplia familia de getters (`getPower`, `getAcceleration`, `getLevel`, `tokenURI`, etc.) expone la información a otros procesos del juego como inscripciones o generación de interfaces, permitiendo validar descansos y consultar atributos en cada etapa.
 */
contract HorseStats {
    string public version = "HorseStats-v1.0.0";

    // ---------------------------------------------------------------------
    // Contract References
    // ---------------------------------------------------------------------
    address public admin;
    address public fixtureManager;
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
        uint256 imgCategory;
        uint256 imgNumber;
        PerformanceStats baseStats;
        PerformanceStats assignedStats;
        PerformanceStats levelStats; // cached levels for each stat
        CooldownStats coolDownStats;
        uint256 totalPoints;
        uint256 unassignedPoints;
        uint256 restFinish;
    }

    mapping(uint256 => HorseData) public horses;
    struct ImgCategoryData {
        string name;
        uint256 maxImgNumber;
        bool exists;
    }

    mapping(uint256 => ImgCategoryData) public imgCategories;
    uint256[] private imgCategoryIds;

    // ---------------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------------
    event HorseCreated(uint256 indexed horseId, uint256 imgCategory, uint256 imgNumber, PerformanceStats baseStats);
    event ImgCategoryConfigured(uint256 indexed imgCategory, string name, uint256 maxImgNumber);
    event HorseStatsUpdated(uint256 indexed horseId, PerformanceStats stats);
    event HorseWonPrize(uint256 indexed horseId, uint256 points);


    modifier onlyAdmin() {
        require(msg.sender == admin, "Not admin");
        _;
    }

    modifier onlyFixtureManager() {
        require(msg.sender == fixtureManager, "Not FixtureManager");
        _;
    }

    modifier onlyHorseMinter() {
        require(msg.sender == horseMinter, "Not horseMinter");
        _;
    }

    constructor() {
        admin = msg.sender;
    }

    function setFixtureManager(address _fixture) external onlyAdmin {
        racingFixture = _fixture;
    }

    function setHayToken(address _token) external onlyAdmin {
        hayToken = _token;
    }

    function setHorseMinter(address _minter) external onlyAdmin {
        horseMinter = _minter;
    }

    function setImgCategory(uint256 imgCategory, string calldata name, uint256 maxImgNumber) external onlyAdmin {
        ImgCategoryData storage data = imgCategories[imgCategory];

        if (!data.exists) {
            imgCategoryIds.push(imgCategory);
            data.exists = true;
        }

        data.name = name;
        data.maxImgNumber = maxImgNumber;

        emit ImgCategoryConfigured(imgCategory, name, maxImgNumber);
    }

    function getImgCategoryIds() external view returns (uint256[] memory) {
        return imgCategoryIds;
    }

    function createHorse(
        uint256 horseId,
        uint256 imgCategory,
        uint256 imgNumber,
        PerformanceStats calldata baseStats
    ) external onlyHorseMinter {
        require(horses[horseId].imgNumber == 0, 'Horse already exists');

        ImgCategoryData memory data = imgCategories[imgCategory];
        require(data.exists, 'Img category not configured');
        require(data.maxImgNumber > 0, 'Img category without images');
        require(imgNumber != 0 && imgNumber <= data.maxImgNumber, 'Invalid img number');

        horses[horseId] = HorseData({
            imgCategory: imgCategory,
            imgNumber: imgNumber,
            baseStats: baseStats,
            assignedStats: PerformanceStats(0, 0, 0, 0, 0, 0, 0, 0),
            levelStats: PerformanceStats(0, 0, 0, 0, 0, 0, 0, 0),
            coolDownStats: CooldownStats(0),
            totalPoints: 0,
            unassignedPoints: 0,
            restFinish: 0
        });

        _setPropertyLevels(horseId);

        emit HorseCreated(horseId, imgCategory, imgNumber, baseStats);
    }

    function getRandomVisual(uint256 entropy) external view returns (uint256 imgCategory, uint256 imgNumber) {
        require(imgCategoryIds.length > 0, 'No img categories configured');

        uint256 validCategories;
        uint256 length = imgCategoryIds.length;
        for (uint256 i = 0; i < length; i++) {
            ImgCategoryData storage data = imgCategories[imgCategoryIds[i]];
            if (data.exists && data.maxImgNumber > 0) {
                validCategories++;
            }
        }

        require(validCategories > 0, 'No categories with images');

        uint256 categorySeed = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, entropy)));
        uint256 categoryIndex = categorySeed % validCategories;

        uint256 selectedCategory = type(uint256).max;
        uint256 counter;
        for (uint256 i = 0; i < length; i++) {
            ImgCategoryData storage data = imgCategories[imgCategoryIds[i]];
            if (data.exists && data.maxImgNumber > 0) {
                if (counter == categoryIndex) {
                    selectedCategory = imgCategoryIds[i];
                    break;
                }
                counter++;
            }
        }

        require(selectedCategory != type(uint256).max, 'Random category selection failed');

        ImgCategoryData storage chosen = imgCategories[selectedCategory];
        uint256 numberSeed = uint256(keccak256(abi.encodePacked(categorySeed, entropy, block.number)));
        uint256 selectedNumber = (numberSeed % chosen.maxImgNumber) + 1;

        return (selectedCategory, selectedNumber);
    }

    function setRacePrize(uint256 horseId, uint256 points) external onlyRacingFixture {
        require(horses[horseId].imgNumber != 0, 'Horse not found');
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
        require(h.imgNumber != 0, 'Horse not found');

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
        require(h.imgNumber != 0, 'Horse not found');
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
        require(h.imgNumber != 0, 'Horse not found');
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

    function isRegisteredForRacing(uint256 horseId) public view returns (bool) {
        return IFixture(racingFixture).isRegistered(horseId);
    }

    function hasFinishedResting(uint256 horseId) public view returns (bool) {
        return block.timestamp >= horses[horseId].restFinish;
    }

    function getAssignedStats(uint256 horseId) public view returns (PerformanceStats memory) {
        return horses[horseId].assignedStats;
    }

    function getBaseStats(uint256 horseId) public view returns (PerformanceStats memory) {
        return horses[horseId].baseStats;
    }

    function getImgCategoryAndNumber(uint256 horseId) public view returns (uint256, uint256) {
        HorseData memory h = horses[horseId];
        return (h.imgCategory, h.imgNumber);
    }

    function getTotalPoints(uint256 horseId) public view returns (uint256) {
        HorseData storage h = horses[horseId];
        require(h.imgNumber != 0, 'Horse not found');
        return horses[horseId].totalPoints;
    }

    function getUnassignedPoints(uint256 horseId) public view returns (uint256) {
        HorseData memory h = horses[horseId];
        require(h.imgNumber != 0, 'Horse not found');
        return h.unassignedPoints;
    }

    function getLevel(uint256 horseId) public view returns (uint256 level) {
        HorseData memory h = horses[horseId];
        require(h.imgNumber != 0, 'Horse not found');
        // level = floor(h.levelStats.power * h.totalPoints / log2(h.totalPoints));
        UFix6 power = UFix6.wrap(h.levelStats.power);
        UFix6 totalPoints = UFix6Lib.fromUint(h.totalPoints);
        UFix6 logTotal = UFix6Lib.log2_uint(h.totalPoints);
        UFix6 result = UFix6Lib.div(UFix6Lib.mul(power, totalPoints), logTotal);
        level = UFix6Lib.toUint(result);
    }

    function getPower(uint256 horseId) public view returns (uint256 power) {
        HorseData memory h = horses[horseId];
        require(h.imgNumber != 0, 'Horse not found');
        uint256 value = h.assignedStats.power + h.baseStats.power;
        // power = 1 + log2(value) * 0.1;
        UFix6 logValue = UFix6Lib.log2_uint(value);
        UFix6 scaled = UFix6Lib.mul(logValue, UFix6.wrap(100000));
        UFix6 result = UFix6Lib.add(UFix6Lib.one(), scaled);
        power = UFix6.unwrap(result);
    }

    function getAcceleration(uint256 horseId) public view returns (uint256 acceleration) {
        HorseData memory h = horses[horseId];
        require(h.imgNumber != 0, 'Horse not found');
        uint256 value = h.baseStats.acceleration + h.assignedStats.acceleration;
        acceleration = _computePerformanceStat(h.levelStats.power, value);
    }

    function getStamina(uint256 horseId) public view returns (uint256 stamina) {
        HorseData memory h = horses[horseId];
        require(h.imgNumber != 0, 'Horse not found');
        uint256 value = h.baseStats.stamina + h.assignedStats.stamina;
        stamina = _computePerformanceStat(h.levelStats.power, value);
    }

    function getMinSpeed(uint256 horseId) public view returns (uint256 minSpeed) {
        HorseData memory h = horses[horseId];
        require(h.imgNumber != 0, 'Horse not found');
        uint256 value = h.baseStats.minSpeed + h.assignedStats.minSpeed;
        minSpeed = _computePerformanceStat(h.levelStats.power, value);
    }

    function getMaxSpeed(uint256 horseId) public view returns (uint256 maxSpeed) {
        HorseData memory h = horses[horseId];
        require(h.imgNumber != 0, 'Horse not found');
        uint256 value = h.baseStats.maxSpeed + h.assignedStats.maxSpeed;
        maxSpeed = _computePerformanceStat(h.levelStats.power, value);
    }

    function getLuck(uint256 horseId) public view returns (uint256 luck) {
        HorseData memory h = horses[horseId];
        require(h.imgNumber != 0, 'Horse not found');
        uint256 value = h.baseStats.luck + h.assignedStats.luck;
        luck = _computePerformanceStat(h.levelStats.power, value);
    }

    function getCurveBonus(uint256 horseId) public view returns (uint256 curveBonus) {
        HorseData memory h = horses[horseId];
        require(h.imgNumber != 0, 'Horse not found');
        uint256 value = h.baseStats.curveBonus + h.assignedStats.curveBonus;
        curveBonus = _computePerformanceStat(h.levelStats.power, value);
    }

    function getStraightBonus(uint256 horseId) public view returns (uint256 straightBonus) {
        HorseData memory h = horses[horseId];
        require(h.imgNumber != 0, 'Horse not found');
        uint256 value = h.baseStats.straightBonus + h.assignedStats.straightBonus;
        straightBonus = _computePerformanceStat(h.levelStats.power, value);
    }

    function getRestingCoolDown(uint256 horseId) public view returns (uint256 resting) {
        HorseData memory h = horses[horseId];
        require(h.imgNumber != 0, 'Horse not found');
        uint256 value = h.coolDownStats.resting;
        resting = _computeCooldownStat(value);
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
        // result = BASE_RESTING_COOLDOWN * 16 / (value + 15)
        UFix6 base = UFix6Lib.fromUint(BASE_RESTING_COOLDOWN);
        UFix6 numerator = UFix6Lib.mulUint(base, 16); // BASE_RESTING_COOLDOWN * 16
        UFix6 denominator = UFix6Lib.fromUint(value + 15);
        UFix6 result = UFix6Lib.div(numerator, denominator);
        return UFix6.unwrap(result);
    }

    // --------------------------------------------------------
    // tokenURI returns directly an updated JSON string
    // --------------------------------------------------------
    function tokenURI(uint256 id) external view virtual returns (string memory) {
        HorseData storage h = horses[id];
        require(h.imgNumber != 0, "Horse not found");

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

    function _getImgCategoryString(uint256 imgCategory) internal view returns (string memory) {
        ImgCategoryData storage data = imgCategories[imgCategory];
        if (!data.exists || bytes(data.name).length == 0) {
            return string.concat("imgCategory-", Strings.toString(imgCategory));
        }
        return data.name;
    }

    function _buildMainBody(uint256 id, HorseData storage h) internal view returns (string memory) {
        string memory idStr = id.toString();
        string memory imgNumberStr = h.imgNumber.toString();
        string memory imgCategoryStr = _getImgCategoryString(h.imgCategory);

        return string.concat(
            '"id": ', idStr, ',',
            '"name": "Horse #', idStr, '",',
            '"description": "Description here",',
            '"imageUrl": "https://tekika-nfts.s3.amazonaws.com/tokens/', imgCategoryStr, '-', imgNumberStr, '.webp",'
        );
    }

    function _buildAttributes(HorseData storage h) internal view returns (string memory) {

        string memory imgCategoryStr = _getImgCategoryString(h.imgCategory);
        string memory powerStr = h.baseStats.power.toString();
        string memory accelerationStr = h.baseStats.acceleration.toString();
        string memory staminaStr = h.baseStats.stamina.toString();
        string memory minSpeedStr = h.baseStats.minSpeed.toString();
        string memory maxSpeedStr = h.baseStats.maxSpeed.toString();
        string memory luckStr = h.baseStats.luck.toString();
        string memory curveBonusStr = h.baseStats.curveBonus.toString();
        string memory straightBonusStr = h.baseStats.straightBonus.toString();

        return string.concat(
            '{"trait_type": "imgCategory", "value": "', imgCategoryStr, '"},',
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

interface IFixture {
    function isRegistered(uint256 horseId) external view returns (bool);
}
