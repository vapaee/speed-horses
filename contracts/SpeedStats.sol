// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

import { PerformanceStats } from "./StatsStructs.sol";
import { HorseStatsModule } from "./modules/HorseStatsModule.sol";
import { HorseshoeStatsModule } from "./modules/HorseshoeStatsModule.sol";

interface IFixtureManagerView {
    function isRegistered(uint256 horseId) external view returns (bool);
}

interface IERC721Minimal {
    function ownerOf(uint256 tokenId) external view returns (address);
}

/// @title SpeedStats
/// @notice Central coordinator that combines horse and horseshoe statistics while delegating
///         storage to dedicated modules. The contract exposes the same external surface that the
///         rest of the ecosystem expects (levels, tokenURI, cooldown checks) but builds the values
///         by composing the underlying modules.
contract SpeedStats {
    using Strings for uint256;

    string public constant version = "SpeedStats-v1.0.0";

    // ---------------------------------------------------------------------
    // Roles
    // ---------------------------------------------------------------------
    address public admin;
    address public fixtureManager;
    address public horseMinter;
    address public hayToken;
    address public speedHorsesToken;
    address public horseshoesToken;

    modifier onlyAdmin() {
        require(msg.sender == admin, "SpeedStats: not admin");
        _;
    }

    modifier onlyHorseMinter() {
        require(msg.sender == horseMinter, "SpeedStats: not horse minter");
        _;
    }

    modifier onlyFixtureManager() {
        require(msg.sender == fixtureManager, "SpeedStats: not fixture");
        _;
    }

    constructor() {
        admin = msg.sender;
    }

    
    // ----------------------------------------------------
    // Admin functions
    // ----------------------------------------------------


    function setAdmin(address newAdmin) external onlyAdmin {
        require(newAdmin != address(0), "SpeedStats: invalid admin");
        admin = newAdmin;
    }

    function setHorseMinter(address _minter) external onlyAdmin {
        horseMinter = _minter;
    }

    function setFixtureManager(address _fixture) external onlyAdmin {
        fixtureManager = _fixture;
    }

    function setHayToken(address _hay) external onlyAdmin {
        hayToken = _hay;
    }

    function setSpeedHorses(address _token) external onlyAdmin {
        speedHorsesToken = _token;
    }

    function setHorseshoes(address _token) external onlyAdmin {
        horseshoesToken = _token;
    }


    // ---------------------------------------------------------------------
    // Module wiring
    // ---------------------------------------------------------------------
    HorseStatsModule public horseModule;
    HorseshoeStatsModule public horseshoeModule;

    function setHorseModule(address module) external onlyAdmin {
        HorseStatsModule candidate = HorseStatsModule(module);
        require(candidate.speedStats() == address(this), "SpeedStats: controller not granted");
        horseModule = candidate;
    }

    function setHorseshoeModule(address module) external onlyAdmin {
        HorseshoeStatsModule candidate = HorseshoeStatsModule(module);
        require(candidate.speedStats() == address(this), "SpeedStats: controller not granted");
        horseshoeModule = candidate;
    }


    // ---------------------------------------------------------------------
    // Configuration proxied to modules
    // ---------------------------------------------------------------------

    function setImgCategory(uint256 imgCategory, string calldata name, uint256 maxImgNumber) external onlyAdmin {
        horseModule.setImgCategory(imgCategory, name, maxImgNumber);
    }

    function getImgCategoryIds() external view returns (uint256[] memory) {
        return horseModule.getImgCategoryIds();
    }

    // ---------------------------------------------------------------------
    // Horse lifecycle
    // ---------------------------------------------------------------------
    event HorseCreated(uint256 indexed horseId, uint256 imgCategory, uint256 imgNumber, PerformanceStats baseStats);
    event HorseAssigned(uint256 indexed horseId, PerformanceStats newAssigned, uint256 spentPoints);
    event HorseRestStarted(uint256 indexed horseId, uint256 restFinish);
    event HorseWonPrize(uint256 indexed horseId, uint256 points);

    uint256 public constant BASE_RESTING_COOLDOWN = 1 days;
    uint256 public constant LEVEL_STEP = 50;
    uint256 public constant FEEDING_COST_PER_POINT = 1 ether;

    function createHorse(
        uint256 horseId,
        uint256 imgCategory,
        uint256 imgNumber,
        PerformanceStats calldata baseStats
    ) external onlyHorseMinter {
        horseModule.createHorse(horseId, imgCategory, imgNumber, baseStats);
        emit HorseCreated(horseId, imgCategory, imgNumber, baseStats);
    }

    function getRandomVisual(uint256 entropy) external view returns (uint256, uint256) {
        return horseModule.getRandomVisual(entropy);
    }

    function setRacePrize(uint256 horseId, uint256 points) external onlyFixtureManager {
        horseModule.addPoints(horseId, points);
        uint256 newRest = block.timestamp + BASE_RESTING_COOLDOWN;
        horseModule.setRestFinish(horseId, newRest);
        emit HorseWonPrize(horseId, points);
        emit HorseRestStarted(horseId, newRest);
    }

    function assignPoints(uint256 horseId, PerformanceStats calldata additional) external {
        require(hayToken != address(0), "SpeedStats: hay token not set");
        uint256 totalToAssign = _sumStats(additional);
        require(totalToAssign > 0, "SpeedStats: nothing to assign");

        HorseStatsModule.HorseData memory data = horseModule.getHorse(horseId);
        require(speedHorsesToken != address(0), "SpeedStats: NFT not set");
        require(IERC721Minimal(speedHorsesToken).ownerOf(horseId) == msg.sender, "SpeedStats: not horse owner");

        horseModule.consumeUnassigned(horseId, totalToAssign);
        IERC20(hayToken).transferFrom(msg.sender, address(this), totalToAssign * FEEDING_COST_PER_POINT);

        PerformanceStats memory updated = _addPerformance(data.assignedStats, additional);
        horseModule.setAssignedStats(horseId, updated);

        emit HorseAssigned(horseId, updated, totalToAssign);
    }

    // ---------------------------------------------------------------------
    // Horseshoe lifecycle
    // ---------------------------------------------------------------------
    event HorseshoeCreated(uint256 indexed horseshoeId, PerformanceStats bonusStats, uint256 maxDurability, uint256 maxAdjustments);
    event HorseshoeEquipped(uint256 indexed horseId, uint256 indexed horseshoeId);
    event HorseshoeUnequipped(uint256 indexed horseId, uint256 indexed horseshoeId);

    mapping(uint256 => uint256[]) private equippedHorseshoes;
    mapping(uint256 => mapping(uint256 => bool)) private horseHasShoe;

    function createHorseshoe(
        uint256 horseshoeId,
        PerformanceStats calldata bonusStats,
        uint256 maxDurability,
        uint256 maxAdjustments
    ) external onlyAdmin {
        horseshoeModule.createHorseshoe(horseshoeId, bonusStats, maxDurability, maxAdjustments);
        emit HorseshoeCreated(horseshoeId, bonusStats, maxDurability, maxAdjustments);
    }

    function equipHorseshoe(uint256 horseId, uint256 horseshoeId) external {
        require(speedHorsesToken != address(0) && horseshoesToken != address(0), "SpeedStats: tokens not set");
        require(IERC721Minimal(speedHorsesToken).ownerOf(horseId) == msg.sender, "SpeedStats: not horse owner");
        require(IERC721Minimal(horseshoesToken).ownerOf(horseshoeId) == msg.sender, "SpeedStats: not horseshoe owner");
        require(!horseHasShoe[horseId][horseshoeId], "SpeedStats: already equipped");

        horseshoeModule.getHorseshoe(horseshoeId); // ensure exists
        horseHasShoe[horseId][horseshoeId] = true;
        equippedHorseshoes[horseId].push(horseshoeId);
        emit HorseshoeEquipped(horseId, horseshoeId);
    }

    function unequipHorseshoe(uint256 horseId, uint256 horseshoeId) external {
        require(speedHorsesToken != address(0) && horseshoesToken != address(0), "SpeedStats: tokens not set");
        require(IERC721Minimal(speedHorsesToken).ownerOf(horseId) == msg.sender, "SpeedStats: not horse owner");
        require(horseHasShoe[horseId][horseshoeId], "SpeedStats: not equipped");

        uint256[] storage list = equippedHorseshoes[horseId];
        for (uint256 i = 0; i < list.length; i++) {
            if (list[i] == horseshoeId) {
                list[i] = list[list.length - 1];
                list.pop();
                break;
            }
        }

        horseHasShoe[horseId][horseshoeId] = false;
        emit HorseshoeUnequipped(horseId, horseshoeId);
    }

    function getEquippedHorseshoes(uint256 horseId) external view returns (uint256[] memory) {
        uint256[] storage list = equippedHorseshoes[horseId];
        uint256[] memory result = new uint256[](list.length);
        for (uint256 i = 0; i < list.length; i++) {
            result[i] = list[i];
        }
        return result;
    }

    // ---------------------------------------------------------------------
    // Views consumed by the ecosystem
    // ---------------------------------------------------------------------

    function getBaseStats(uint256 horseId) public view returns (PerformanceStats memory) {
        HorseStatsModule.HorseData memory data = horseModule.getHorse(horseId);
        return data.baseStats;
    }

    function getAssignedStats(uint256 horseId) public view returns (PerformanceStats memory) {
        HorseStatsModule.HorseData memory data = horseModule.getHorse(horseId);
        return data.assignedStats;
    }

    function getEquipmentBonus(uint256 horseId) public view returns (PerformanceStats memory totalBonus) {
        uint256[] storage list = equippedHorseshoes[horseId];
        totalBonus = PerformanceStats(0, 0, 0, 0, 0, 0, 0, 0);
        for (uint256 i = 0; i < list.length; i++) {
            HorseshoeStatsModule.HorseshoeData memory shoe = horseshoeModule.getHorseshoe(list[i]);
            totalBonus = _addPerformance(totalBonus, shoe.bonusStats);
        }
    }

    function getPerformance(uint256 horseId) public view returns (PerformanceStats memory) {
        PerformanceStats memory baseStats = getBaseStats(horseId);
        PerformanceStats memory assigned = getAssignedStats(horseId);
        PerformanceStats memory equipment = getEquipmentBonus(horseId);
        PerformanceStats memory total = _addPerformance(baseStats, assigned);
        return _addPerformance(total, equipment);
    }

    function getTotalPoints(uint256 horseId) public view returns (uint256) {
        HorseStatsModule.HorseData memory data = horseModule.getHorse(horseId);
        uint256 equipmentPoints = _sumStats(getEquipmentBonus(horseId));
        return data.totalPoints + equipmentPoints;
    }

    function getLevel(uint256 horseId) public view returns (uint256) {
        uint256 total = getTotalPoints(horseId);
        if (total == 0) {
            return 0;
        }
        return (total / LEVEL_STEP) + 1;
    }

    function hasFinishedResting(uint256 horseId) public view returns (bool) {
        HorseStatsModule.HorseData memory data = horseModule.getHorse(horseId);
        return block.timestamp >= data.restFinish;
    }

    function isRegisteredForRacing(uint256 horseId) public view returns (bool) {
        if (fixtureManager == address(0)) {
            return false;
        }
        return IFixtureManagerView(fixtureManager).isRegistered(horseId);
    }

    function tokenURI(uint256 horseId) external view returns (string memory) {
        HorseStatsModule.HorseData memory data = horseModule.getHorse(horseId);
        PerformanceStats memory totalStats = getPerformance(horseId);

        string memory attributes = string(
            abi.encodePacked(
                '[',
                _attributeJson("Power", totalStats.power), ',',
                _attributeJson("Acceleration", totalStats.acceleration), ',',
                _attributeJson("Stamina", totalStats.stamina), ',',
                _attributeJson("Min Speed", totalStats.minSpeed), ',',
                _attributeJson("Max Speed", totalStats.maxSpeed), ',',
                _attributeJson("Luck", totalStats.luck), ',',
                _attributeJson("Curve Bonus", totalStats.curveBonus), ',',
                _attributeJson("Straight Bonus", totalStats.straightBonus),
                ']'
            )
        );

        string memory json = string(
            abi.encodePacked(
                '{',
                '"name":"Speed Horse #', horseId.toString(), '",',
                '"description":"Composite statistics between the horse and its equipped horseshoes.",',
                '"image":"ipfs://category/', data.imgCategory.toString(), '/', data.imgNumber.toString(), '",',
                '"level":', getLevel(horseId).toString(), ',',
                '"totalPoints":', getTotalPoints(horseId).toString(), ',',
                '"attributes":', attributes,
                '}'
            )
        );

        return string(abi.encodePacked("data:application/json;utf8,", json));
    }

    // ---------------------------------------------------------------------
    // Internal helpers
    // ---------------------------------------------------------------------

    function _attributeJson(string memory trait, uint256 value) internal pure returns (string memory) {
        return string(abi.encodePacked('{"trait_type":"', trait, '","value":', value.toString(), '}'));
    }

    function _addPerformance(PerformanceStats memory a, PerformanceStats memory b)
        internal
        pure
        returns (PerformanceStats memory)
    {
        return
            PerformanceStats({
                power: a.power + b.power,
                acceleration: a.acceleration + b.acceleration,
                stamina: a.stamina + b.stamina,
                minSpeed: a.minSpeed + b.minSpeed,
                maxSpeed: a.maxSpeed + b.maxSpeed,
                luck: a.luck + b.luck,
                curveBonus: a.curveBonus + b.curveBonus,
                straightBonus: a.straightBonus + b.straightBonus
            });
    }

    function _sumStats(PerformanceStats memory stats) internal pure returns (uint256) {
        return
            stats.power +
            stats.acceleration +
            stats.stamina +
            stats.minSpeed +
            stats.maxSpeed +
            stats.luck +
            stats.curveBonus +
            stats.straightBonus;
    }
}
