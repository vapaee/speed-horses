// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

import { PerformanceStats } from "./SpeedH_StatsStructs.sol";
import { SpeedH_Stats_Horse } from "./SpeedH_Stats_Horse.sol";
import { SpeedH_Stats_Horseshoe } from "./SpeedH_Stats_Horseshoe.sol";

interface IFixtureManagerView {
    function isRegistered(uint256 horseId) external view returns (bool);
}

interface IERC721Minimal {
    function ownerOf(uint256 tokenId) external view returns (address);
}

/// @title SpeedH_Stats
/// @notice Central coordinator that composes horse stats (base + assigned + equipped horseshoes)
///         while delegating storage/mutations to modules.
contract SpeedH_Stats {
    using Strings for uint256;

    string public constant version = "SpeedH_Stats-v1.0.2";

    // ---------------------------------------------------------------------
    // Roles
    // ---------------------------------------------------------------------
    address public admin;
    address public fixtureManager;
    mapping(address => bool) private _horseMinters;
    address public hayToken;
    address public speedHorsesToken;
    address public horseshoesToken;

    modifier onlyAdmin() {
        require(msg.sender == admin, "SpeedH_Stats: not admin");
        _;
    }

    modifier onlyHorseMinter() {
        require(_horseMinters[msg.sender], "SpeedH_Stats: not horse minter");
        _;
    }

    modifier onlyFixtureManager() {
        require(msg.sender == fixtureManager, "SpeedH_Stats: not fixture");
        _;
    }

    constructor() {
        admin = msg.sender;
    }

    // ----------------------------------------------------
    // Admin functions
    // ----------------------------------------------------

    function setAdmin(address newAdmin) external onlyAdmin {
        require(newAdmin != address(0), "SpeedH_Stats: invalid admin");
        admin = newAdmin;
    }

    event HorseMinterUpdated(address indexed minter, bool allowed);

    function setHorseMinter(address minter, bool allowed) external onlyAdmin {
        require(minter != address(0), "SpeedH_Stats: invalid minter");
        _horseMinters[minter] = allowed;
        emit HorseMinterUpdated(minter, allowed);
    }

    function isHorseMinter(address minter) external view returns (bool) {
        return _horseMinters[minter];
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
    SpeedH_Stats_Horse public horseModule;
    SpeedH_Stats_Horseshoe public horseshoeModule;

    function setHorseModule(address module) external onlyAdmin {
        SpeedH_Stats_Horse candidate = SpeedH_Stats_Horse(module);
        require(candidate.speedStats() == address(this), "SpeedH_Stats: controller not granted");
        horseModule = candidate;
    }

    function setHorseshoeModule(address module) external onlyAdmin {
        SpeedH_Stats_Horseshoe candidate = SpeedH_Stats_Horseshoe(module);
        require(candidate.speedStats() == address(this), "SpeedH_Stats: controller not granted");
        horseshoeModule = candidate;
    }


    // ---------------------------------------------------------------------
    // Configuration proxied to modules
    // ---------------------------------------------------------------------
    function setHorseImgCategory(uint256 imgCategory, string calldata name, uint256 maxImgNumber) external onlyAdmin {
        horseModule.setImgCategory(imgCategory, name, maxImgNumber);
    }

    function getHorseImgCategoryIds() external view returns (uint256[] memory) {
        return horseModule.getImgCategoryIds();
    }
    function setHorseshoeImgCategory(uint256 imgCategory, string calldata name, uint256 maxImgNumber)
        external
        onlyAdmin
    {
        horseshoeModule.setImgCategory(imgCategory, name, maxImgNumber);
    }

    function getHorseshoeImgCategoryIds() external view returns (uint256[] memory) {
        return horseshoeModule.getImgCategoryIds();
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

    function setRacePrize(uint256 horseId, uint256 points) external onlyFixtureManager {
        horseModule.addPoints(horseId, points);
        uint256 newRest = block.timestamp + BASE_RESTING_COOLDOWN;
        horseModule.setRestFinish(horseId, newRest);
        emit HorseWonPrize(horseId, points);
        emit HorseRestStarted(horseId, newRest);
    }

    function assignPoints(uint256 horseId, PerformanceStats calldata additional) external {
        require(hayToken != address(0), "SpeedH_Stats: hay token not set");
        uint256 totalToAssign = _sumStats(additional);
        require(totalToAssign > 0, "SpeedH_Stats: nothing to assign");

        SpeedH_Stats_Horse.HorseData memory data = horseModule.getHorse(horseId);
        require(speedHorsesToken != address(0), "SpeedH_Stats: NFT not set");
        require(IERC721Minimal(speedHorsesToken).ownerOf(horseId) == msg.sender, "SpeedH_Stats: not horse owner");

        horseModule.consumeUnassigned(horseId, totalToAssign);
        IERC20(hayToken).transferFrom(msg.sender, address(this), totalToAssign * FEEDING_COST_PER_POINT);

        PerformanceStats memory updated = _addPerformance(data.assignedStats, additional);
        horseModule.setAssignedStats(horseId, updated);

        emit HorseAssigned(horseId, updated, totalToAssign);
    }

    // ---------------------------------------------------------------------
    // Horseshoe lifecycle
    // ---------------------------------------------------------------------

    /// @dev maxAdjustments removed to match SpeedH_Stats_Horseshoe; event updated accordingly.
    event HorseshoeCreated(
        uint256 indexed horseshoeId,
        uint256 imgCategory,
        uint256 imgNumber,
        PerformanceStats bonusStats,
        uint256 maxDurability,
        uint256 level,
        bool pure
    );
    event HorseshoeEquipped(uint256 indexed horseId, uint256 indexed horseshoeId);
    event HorseshoeUnequipped(uint256 indexed horseId, uint256 indexed horseshoeId);

    // hard cap of 4 shoe slots per horse
    uint256 public constant MAX_SHOE_SLOTS = 4;

    // horseId => list of equipped horseshoe tokenIds
    mapping(uint256 => uint256[]) private equippedHorseshoes;
    // horseId => horseshoeId => bool
    mapping(uint256 => mapping(uint256 => bool)) private horseHasShoe;
    // horseshoeId => whether the horseshoe is currently equipped on any horse
    mapping(uint256 => bool) private horseshoeEquipped;

    /// @notice Create a new horseshoe record in the module (admin operation).
    function createHorseshoe(
        uint256 horseshoeId,
        uint256 imgCategory,
        uint256 imgNumber,
        PerformanceStats calldata bonusStats,
        uint256 maxDurability,
        uint256 level,
        bool pure
    ) external onlyAdmin {
        horseshoeModule.createHorseshoe(horseshoeId, imgCategory, imgNumber, bonusStats, maxDurability, level, pure);
        emit HorseshoeCreated(horseshoeId, imgCategory, imgNumber, bonusStats, maxDurability, level, pure);
    }

    function registerForgedHorseshoe(
        uint256 horseshoeId,
        uint256 imgCategory,
        uint256 imgNumber,
        PerformanceStats calldata bonusStats,
        uint256 maxDurability,
        uint256 level,
        bool pure
    ) external onlyHorseMinter {
        horseshoeModule.createHorseshoe(horseshoeId, imgCategory, imgNumber, bonusStats, maxDurability, level, pure);
        emit HorseshoeCreated(horseshoeId, imgCategory, imgNumber, bonusStats, maxDurability, level, pure);
    }

    /// @notice Hook used by the minter to materialize the starter horseshoes and equip them immediately.
    function createStarterHorseshoe(
        uint256 horseId,
        uint256 horseshoeId,
        uint256 imgCategory,
        uint256 imgNumber,
        PerformanceStats calldata bonusStats,
        uint256 maxDurability,
        uint256 level,
        bool pure
    ) external onlyHorseMinter {
        require(address(horseshoeModule) != address(0), "SpeedH_Stats: horseshoe module not set");
        require(address(horseModule) != address(0), "SpeedH_Stats: horse module not set");
        require(speedHorsesToken != address(0) && horseshoesToken != address(0), "SpeedH_Stats: tokens not set");

        bool exists = true;
        try horseshoeModule.getHorseshoe(horseshoeId) returns (SpeedH_Stats_Horseshoe.HorseshoeData memory /*existing*/) {
            // Horseshoe already registered, nothing else to do before equipping.
        } catch {
            exists = false;
        }

        if (!exists) {
            horseshoeModule.createHorseshoe(horseshoeId, imgCategory, imgNumber, bonusStats, maxDurability, level, pure);
            emit HorseshoeCreated(horseshoeId, imgCategory, imgNumber, bonusStats, maxDurability, level, pure);
        }

        // Will revert if the horse does not exist
        horseModule.getHorse(horseId);

        address horseOwner = IERC721Minimal(speedHorsesToken).ownerOf(horseId);
        require(horseOwner == IERC721Minimal(horseshoesToken).ownerOf(horseshoeId), "SpeedH_Stats: mismatched owner");

        uint256[] storage list = equippedHorseshoes[horseId];
        require(list.length < MAX_SHOE_SLOTS, "SpeedH_Stats: all slots occupied");
        require(!horseHasShoe[horseId][horseshoeId], "SpeedH_Stats: already equipped");
        require(!horseshoeEquipped[horseshoeId], "SpeedH_Stats: horseshoe in use");

        horseHasShoe[horseId][horseshoeId] = true;
        horseshoeEquipped[horseshoeId] = true;
        list.push(horseshoeId);

        emit HorseshoeEquipped(horseId, horseshoeId);
    }

    /// @notice Equip a horseshoe into one of the limited slots of the horse.
    function equipHorseshoe(uint256 horseId, uint256 horseshoeId) external {
        require(speedHorsesToken != address(0) && horseshoesToken != address(0), "SpeedH_Stats: tokens not set");
        require(IERC721Minimal(speedHorsesToken).ownerOf(horseId) == msg.sender, "SpeedH_Stats: not horse owner");
        require(IERC721Minimal(horseshoesToken).ownerOf(horseshoeId) == msg.sender, "SpeedH_Stats: not horseshoe owner");
        require(!horseHasShoe[horseId][horseshoeId], "SpeedH_Stats: already equipped");
        require(!horseshoeEquipped[horseshoeId], "SpeedH_Stats: horseshoe in use");

        uint256[] storage list = equippedHorseshoes[horseId];
        require(list.length < MAX_SHOE_SLOTS, "SpeedH_Stats: all slots occupied");

        // ensure horseshoe exists (will revert otherwise)
        horseshoeModule.getHorseshoe(horseshoeId);

        horseHasShoe[horseId][horseshoeId] = true;
        horseshoeEquipped[horseshoeId] = true;
        list.push(horseshoeId);

        emit HorseshoeEquipped(horseId, horseshoeId);
    }

    /// @notice Unequip a horseshoe. Blocked if the horse is registered for racing.
    function unequipHorseshoe(uint256 horseId, uint256 horseshoeId) external {
        require(speedHorsesToken != address(0) && horseshoesToken != address(0), "SpeedH_Stats: tokens not set");
        require(IERC721Minimal(speedHorsesToken).ownerOf(horseId) == msg.sender, "SpeedH_Stats: not horse owner");
        require(horseHasShoe[horseId][horseshoeId], "SpeedH_Stats: not equipped");

        // Block unequip while registered for racing
        require(!isRegisteredForRacing(horseId), "SpeedH_Stats: horse registered for racing");

        uint256[] storage list = equippedHorseshoes[horseId];
        for (uint256 i = 0; i < list.length; i++) {
            if (list[i] == horseshoeId) {
                list[i] = list[list.length - 1];
                list.pop();
                break;
            }
        }

        horseHasShoe[horseId][horseshoeId] = false;
        horseshoeEquipped[horseshoeId] = false;
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

    function isHorseshoeEquipped(uint256 horseshoeId) external view returns (bool) {
        return horseshoeEquipped[horseshoeId];
    }

    /// @notice Consume durability from all equipped horseshoes of the given horse.
    /// @dev Restricted to fixture manager (typical lifecycle: consume on race end).
    /// @param horseId The horse NFT id
    /// @param lessPerShoe The durability amount to consume per equipped horseshoe
    function consumeEquippedDurability(uint256 horseId, uint256 lessPerShoe) external onlyFixtureManager {
        require(lessPerShoe > 0, "SpeedH_Stats: invalid amount");
        uint256[] storage list = equippedHorseshoes[horseId];
        require(list.length > 0, "SpeedH_Stats: no horseshoes equipped");

        // Iterate and consume durability on each equipped horseshoe.
        // This call will revert if SpeedH_Stats_Horseshoe' internal checks fail.
        for (uint256 i = 0; i < list.length; i++) {
            horseshoeModule.consume(list[i], lessPerShoe);
        }
    }

    // ---------------------------------------------------------------------
    // Views consumed by the ecosystem
    // ---------------------------------------------------------------------

    function getBaseStats(uint256 horseId) public view returns (PerformanceStats memory) {
        SpeedH_Stats_Horse.HorseData memory data = horseModule.getHorse(horseId);
        return data.baseStats;
    }

    function getAssignedStats(uint256 horseId) public view returns (PerformanceStats memory) {
        SpeedH_Stats_Horse.HorseData memory data = horseModule.getHorse(horseId);
        return data.assignedStats;
    }

    function getEquipmentBonus(uint256 horseId) public view returns (PerformanceStats memory totalBonus) {
        uint256[] storage list = equippedHorseshoes[horseId];
        totalBonus = PerformanceStats(0, 0, 0, 0, 0, 0, 0, 0);
        for (uint256 i = 0; i < list.length; i++) {
            SpeedH_Stats_Horseshoe.HorseshoeData memory shoe = horseshoeModule.getHorseshoe(list[i]);
            totalBonus = _addPerformance(totalBonus, shoe.bonusStats);
        }
    }

    function getRandomHorseshoeVisual(uint256 entropy) external view returns (uint256, uint256) {
        require(address(horseshoeModule) != address(0), "SpeedH_Stats: horseshoe module not set");
        return horseshoeModule.getRandomVisual(entropy);
    }

    function getPerformance(uint256 horseId) public view returns (PerformanceStats memory) {
        PerformanceStats memory baseStats = getBaseStats(horseId);
        PerformanceStats memory assigned = getAssignedStats(horseId);
        PerformanceStats memory equipment = getEquipmentBonus(horseId);
        PerformanceStats memory total = _addPerformance(baseStats, assigned);
        return _addPerformance(total, equipment);
    }

    function getHorsePerformance(uint256 horseId) public view returns (PerformanceStats memory) {
        PerformanceStats memory baseStats = getBaseStats(horseId);
        PerformanceStats memory assigned = getAssignedStats(horseId);
        return _addPerformance(baseStats, assigned);
    }        

    function getTotalPoints(uint256 horseId) public view returns (uint256) {
        SpeedH_Stats_Horse.HorseData memory data = horseModule.getHorse(horseId);
        uint256 equipmentPoints = _sumStats(getEquipmentBonus(horseId));
        return data.totalPoints + equipmentPoints;
    }

    function getHorseTotalPoints(uint256 horseId) public view returns (uint256) {
        SpeedH_Stats_Horse.HorseData memory data = horseModule.getHorse(horseId);
        return data.totalPoints;
    }

    function getLevel(uint256 horseId) public view returns (uint256) {
        uint256 total = getTotalPoints(horseId);
        if (total == 0) {
            return 0;
        }
        return (total / LEVEL_STEP) + 1;
    }

    function hasFinishedResting(uint256 horseId) public view returns (bool) {
        SpeedH_Stats_Horse.HorseData memory data = horseModule.getHorse(horseId);
        return block.timestamp >= data.restFinish;
    }

    function isRegisteredForRacing(uint256 horseId) public view returns (bool) {
        if (fixtureManager == address(0)) {
            return false;
        }
        return IFixtureManagerView(fixtureManager).isRegistered(horseId);
    }

    // returns all JSON metadata for the given horseId
    function horseTokenURI(uint256 horseId) external view returns (string memory) {
        SpeedH_Stats_Horse.HorseData memory data = horseModule.getHorse(horseId);
        PerformanceStats memory totalStats = getHorsePerformance(horseId);

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

        string memory categoryName = horseModule.getImgCategoryName(data.imgCategory);
        string memory categoryPath = _categoryPathSegment(categoryName, data.imgCategory);

        string memory json = string(
            abi.encodePacked(
                '{',
                '"name":"Speed Horse #', horseId.toString(), '",',
                '"description":"Composite statistics between the horse and its equipped horseshoes.",',
                '"image":"ipfs://category/', categoryPath, '/', data.imgNumber.toString(), '",',
                '"level":', getLevel(horseId).toString(), ',',
                '"totalPoints":', getTotalPoints(horseId).toString(), ',',
                '"attributes":', attributes,
                '}'
            )
        );

        return string(abi.encodePacked("data:application/json;utf8,", json));
    }

    // returns all JSON metadata for the given horseshoeId
    function horseshoeTokenURI(uint256 horseshoeId) external view returns (string memory) {
        SpeedH_Stats_Horseshoe.HorseshoeData memory data = horseshoeModule.getHorseshoe(horseshoeId);
        string memory attributes = '[';
        bool isFirst = true;

        (attributes, isFirst) = _appendAttributeIfNonZero(attributes, "Power", data.bonusStats.power, isFirst);
        (attributes, isFirst) = _appendAttributeIfNonZero(attributes, "Acceleration", data.bonusStats.acceleration, isFirst);
        (attributes, isFirst) = _appendAttributeIfNonZero(attributes, "Stamina", data.bonusStats.stamina, isFirst);
        (attributes, isFirst) = _appendAttributeIfNonZero(attributes, "Min Speed", data.bonusStats.minSpeed, isFirst);
        (attributes, isFirst) = _appendAttributeIfNonZero(attributes, "Max Speed", data.bonusStats.maxSpeed, isFirst);
        (attributes, isFirst) = _appendAttributeIfNonZero(attributes, "Luck", data.bonusStats.luck, isFirst);
        (attributes, isFirst) = _appendAttributeIfNonZero(attributes, "Curve Bonus", data.bonusStats.curveBonus, isFirst);
        (attributes, isFirst) = _appendAttributeIfNonZero(attributes, "Straight Bonus", data.bonusStats.straightBonus, isFirst);
        (attributes, isFirst) = _appendAttributeIfNonZero(attributes, "Durability", data.durabilityUsed, isFirst);
        (attributes, isFirst) = _appendAttributeIfNonZero(attributes, "Max Durability", data.maxDurability, isFirst);
        (attributes, isFirst) = _appendAttributeIfNonZero(attributes, "Level", data.level, isFirst);

        string memory pureValue = data.pure ? "Yes" : "No";
        string memory pureEntry = string(abi.encodePacked('{"trait_type":"Pure","value":"', pureValue, '"}'));
        string memory separator = isFirst ? "" : ",";
        attributes = string(abi.encodePacked(attributes, separator, pureEntry));
        isFirst = false;

        attributes = string(abi.encodePacked(attributes, ']'));

        string memory categoryName = horseshoeModule.getImgCategoryName(data.imgCategory);
        string memory categoryPath = _categoryPathSegment(categoryName, data.imgCategory);

        string memory json = string(
            abi.encodePacked(
                '{',
                '"name":"Horseshoe #', horseshoeId.toString(), '",',
                '"description":"A horseshoe that can be equipped to a Speed Horse to enhance its performance.",',
                '"image":"ipfs://category/', categoryPath, '/', data.imgNumber.toString(), '",',
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

    function _categoryPathSegment(string memory categoryName, uint256 fallbackId)
        internal
        pure
        returns (string memory)
    {
        if (bytes(categoryName).length > 0) {
            return categoryName;
        }
        return fallbackId.toString();
    }

    function _appendAttributeIfNonZero(
        string memory current,
        string memory trait,
        uint256 value,
        bool isFirst
    ) internal pure returns (string memory, bool) {
        if (value == 0) {
            return (current, isFirst);
        }

        string memory separator = isFirst ? "" : ",";
        string memory updated = string(
            abi.encodePacked(current, separator, _attributeJson(trait, value))
        );

        return (updated, false);
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
