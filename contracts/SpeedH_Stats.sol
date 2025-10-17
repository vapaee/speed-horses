// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { PerformanceStats } from "./SpeedH_StatsStructs.sol";
import { SpeedH_Stats_Horse } from "./SpeedH_Stats_Horse.sol";
import { SpeedH_Stats_Horseshoe } from "./SpeedH_Stats_Horseshoe.sol";
import { UFix6, SpeedH_UFix6Lib } from "./SpeedH_UFix6Lib.sol";
import { SpeedH_Metadata_Horse } from "./SpeedH_Metadata_Horse.sol";
import { SpeedH_Metadata_Horseshoe } from "./SpeedH_Metadata_Horseshoe.sol";

interface IFixtureManagerView {
    function isRegistered(uint256 horseId) external view returns (bool);
}

interface IERC721Minimal {
    function ownerOf(uint256 tokenId) external view returns (address);
}

error NotAdmin();
error NotHorseMinter();
error NotFixtureManager();
error ZeroAddress();
error HorseModuleNotSet();
error HorseshoeModuleNotSet();
error HayTokenNotSet();
error HorseTokenNotSet();
error TokensNotConfigured();
error NothingToAssign();
error NotHorseOwner();
error NotHorseshoeOwner();
error AlreadyEquipped();
error HorseshoeInUse();
error HorseshoeNotUseful();
error SlotsFull();
error MismatchedOwner();
error NotEquipped();
error HorseRegistered();
error InvalidAmount();
error NoHorseshoesEquipped();
error HorseMetadataNotSet();
error HorseshoeMetadataNotSet();
error ModuleNotGranted();

/// @title SpeedH_Stats
/// @notice Central coordinator that composes horse stats (aggregated base + assigned + equipped horseshoes)
///         while delegating storage/mutations to modules.
contract SpeedH_Stats {
    using SafeERC20 for IERC20;

    string public version = "SpeedH_Stats-v1.0.0";

    // ---------------------------------------------------------------------
    // Roles
    // ---------------------------------------------------------------------
    address public admin;
    address public fixtureManager;
    mapping(address => bool) private _horseMinters;
    address public hayToken;
    address public speedHorsesToken;
    address public horseshoesToken;

    SpeedH_Metadata_Horse public horseMetadata;
    SpeedH_Metadata_Horseshoe public horseshoeMetadata;

    constructor() {
        admin = msg.sender;
    }

    function _requireAdmin() internal view {
        if (msg.sender != admin) revert NotAdmin();
    }

    function _requireHorseMinter() internal view {
        if (!_horseMinters[msg.sender]) revert NotHorseMinter();
    }

    function _requireFixtureManager() internal view {
        if (msg.sender != fixtureManager) revert NotFixtureManager();
    }

    function _requireHorseModule() internal view {
        if (address(horseModule) == address(0)) revert HorseModuleNotSet();
    }

    function _requireHorseshoeModule() internal view {
        if (address(horseshoeModule) == address(0)) revert HorseshoeModuleNotSet();
    }

    function _requireHorseMetadata() internal view {
        if (address(horseMetadata) == address(0)) revert HorseMetadataNotSet();
    }

    function _requireHorseshoeMetadata() internal view {
        if (address(horseshoeMetadata) == address(0)) revert HorseshoeMetadataNotSet();
    }

    function _requireTokensConfigured() internal view {
        if (speedHorsesToken == address(0) || horseshoesToken == address(0)) revert TokensNotConfigured();
    }

    function _requireHorseToken() internal view {
        if (speedHorsesToken == address(0)) revert HorseTokenNotSet();
    }

    function _requireHayToken() internal view {
        if (hayToken == address(0)) revert HayTokenNotSet();
    }

    // ----------------------------------------------------
    // Admin functions
    // ----------------------------------------------------

    function setAdmin(address newAdmin) external {
        _requireAdmin();
        if (newAdmin == address(0)) revert ZeroAddress();
        admin = newAdmin;
    }

    event HorseMinterUpdated(address indexed minter, bool allowed);

    function setHorseMinter(address minter, bool allowed) external {
        _requireAdmin();
        if (minter == address(0)) revert ZeroAddress();
        _horseMinters[minter] = allowed;
        emit HorseMinterUpdated(minter, allowed);
    }

    function isHorseMinter(address minter) external view returns (bool) {
        return _horseMinters[minter];
    }

    function setFixtureManager(address _fixture) external {
        _requireAdmin();
        if (_fixture == address(0)) revert ZeroAddress();
        fixtureManager = _fixture;
    }

    function setHayToken(address _hay) external {
        _requireAdmin();
        if (_hay == address(0)) revert ZeroAddress();
        hayToken = _hay;
    }

    function setSpeedHorses(address _token) external {
        _requireAdmin();
        if (_token == address(0)) revert ZeroAddress();
        speedHorsesToken = _token;
    }

    function setHorseshoes(address _token) external {
        _requireAdmin();
        if (_token == address(0)) revert ZeroAddress();
        horseshoesToken = _token;
    }

    // ---------------------------------------------------------------------
    // Module wiring
    // ---------------------------------------------------------------------
    SpeedH_Stats_Horse public horseModule;
    SpeedH_Stats_Horseshoe public horseshoeModule;

    function setHorseModule(address module) external {
        _requireAdmin();
        if (module == address(0)) revert ZeroAddress();
        SpeedH_Stats_Horse candidate = SpeedH_Stats_Horse(module);
        if (candidate.speedStats() != address(this)) revert ModuleNotGranted();
        horseModule = candidate;
    }

    function setHorseshoeModule(address module) external {
        _requireAdmin();
        if (module == address(0)) revert ZeroAddress();
        SpeedH_Stats_Horseshoe candidate = SpeedH_Stats_Horseshoe(module);
        if (candidate.speedStats() != address(this)) revert ModuleNotGranted();
        horseshoeModule = candidate;
    }

    function setHorseMetadata(address metadata) external {
        _requireAdmin();
        if (metadata == address(0)) revert ZeroAddress();
        horseMetadata = SpeedH_Metadata_Horse(metadata);
    }

    function setHorseshoeMetadata(address metadata) external {
        _requireAdmin();
        if (metadata == address(0)) revert ZeroAddress();
        horseshoeMetadata = SpeedH_Metadata_Horseshoe(metadata);
    }


    // ---------------------------------------------------------------------
    // Configuration proxied to modules
    // ---------------------------------------------------------------------
    function setHorseImgCategory(uint256 imgCategory, string calldata name, uint256 maxImgNumber) external {
        _requireAdmin();
        _requireHorseModule();
        horseModule.setImgCategory(imgCategory, name, maxImgNumber);
    }

    function getHorseImgCategoryIds() external view returns (uint256[] memory) {
        _requireHorseModule();
        return horseModule.getImgCategoryIds();
    }
    function setHorseshoeImgCategory(uint256 imgCategory, string calldata name, uint256 maxImgNumber)
        external
    {
        _requireAdmin();
        _requireHorseshoeModule();
        horseshoeModule.setImgCategory(imgCategory, name, maxImgNumber);
    }

    function getHorseshoeImgCategoryIds() external view returns (uint256[] memory) {
        _requireHorseshoeModule();
        return horseshoeModule.getImgCategoryIds();
    }

    // ---------------------------------------------------------------------
    // Horse lifecycle
    // ---------------------------------------------------------------------
    event HorseCreated(uint256 indexed horseId, uint256 imgCategory, uint256 imgNumber, PerformanceStats stats);
    event HorseAssigned(uint256 indexed horseId, PerformanceStats newStats, uint256 spentPoints);
    event HorseRestStarted(uint256 indexed horseId, uint256 restFinish);
    event HorseWonPrize(uint256 indexed horseId, uint256 points);

    uint256 public constant BASE_RESTING_COOLDOWN = 1 days;
    uint256 public constant FEEDING_COST_PER_POINT = 1 ether;

    function createHorseStats(
        uint256 horseId,
        uint256 imgCategory,
        uint256 imgNumber,
        PerformanceStats calldata stats
    ) external {
        _requireHorseMinter();
        _requireHorseModule();
        horseModule.createHorseStats(horseId, imgCategory, imgNumber, stats);
        emit HorseCreated(horseId, imgCategory, imgNumber, stats);
    }

    function setRacePrize(uint256 horseId, uint256 points) external {
        _requireFixtureManager();
        _requireHorseModule();
        horseModule.addPoints(horseId, points);
        uint256 newRest = block.timestamp + BASE_RESTING_COOLDOWN;
        horseModule.setRestFinish(horseId, newRest);
        emit HorseWonPrize(horseId, points);
        emit HorseRestStarted(horseId, newRest);
    }

    function assignPoints(uint256 horseId, PerformanceStats calldata additional) external {
        _requireHorseModule();
        _requireHayToken();
        uint256 totalToAssign = _sumStats(additional);
        if (totalToAssign == 0) revert NothingToAssign();

        SpeedH_Stats_Horse.HorseData memory data = horseModule.getHorse(horseId);
        _requireHorseToken();
        if (IERC721Minimal(speedHorsesToken).ownerOf(horseId) != msg.sender) revert NotHorseOwner();

        horseModule.consumeUnassigned(horseId, totalToAssign);
        IERC20(hayToken).safeTransferFrom(msg.sender, address(this), totalToAssign * FEEDING_COST_PER_POINT);

        PerformanceStats memory updated = _addPerformance(data.stats, additional);
        horseModule.setStats(horseId, updated);

        emit HorseAssigned(horseId, updated, totalToAssign);
    }

    // ---------------------------------------------------------------------
    // Horseshoe lifecycle
    // ---------------------------------------------------------------------

    /// @dev maxAdjustments removed to match SpeedH_Stats_Horseshoe; event updated accordingly.
    event HorseshoeStats(
        uint256 indexed horseshoeId,
        uint256 imgCategory,
        uint256 imgNumber,
        PerformanceStats bonusStats,
        uint256 maxDurability,
        uint256 level,
        bool isPure
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

    function registerHorseshoeStats(
        uint256 horseshoeId,
        uint256 imgCategory,
        uint256 imgNumber,
        PerformanceStats calldata bonusStats,
        uint256 maxDurability,
        uint256 level,
        bool isPure
    ) external {
        _requireHorseMinter();
        _registerHorseshoeStats(
            horseshoeId,
            imgCategory,
            imgNumber,
            bonusStats,
            maxDurability,
            level,
            isPure
        );
    }

    /// @notice Hook used by the minter to materialize the starter horseshoes and equip them immediately.
    function registerStarterHorseshoeStats(
        uint256 horseId,
        uint256 horseshoeId,
        uint256 imgCategory,
        uint256 imgNumber,
        PerformanceStats calldata bonusStats,
        uint256 maxDurability,
        uint256 level,
        bool isPure
    ) external {
        _requireHorseMinter();
        _requireHorseshoeModule();
        _requireHorseModule();
        _requireTokensConfigured();
        // Create the horseshoe record
        _registerHorseshoeStats(
            horseshoeId,
            imgCategory,
            imgNumber,
            bonusStats,
            maxDurability,
            level,
            isPure
        );

        // Will revert if the horse does not exist
        horseModule.getHorse(horseId);

        address horseOwner = IERC721Minimal(speedHorsesToken).ownerOf(horseId);
        if (horseOwner != IERC721Minimal(horseshoesToken).ownerOf(horseshoeId)) revert MismatchedOwner();

        uint256[] storage list = equippedHorseshoes[horseId];
        if (list.length >= MAX_SHOE_SLOTS) revert SlotsFull();
        if (horseHasShoe[horseId][horseshoeId]) revert AlreadyEquipped();
        if (horseshoeEquipped[horseshoeId]) revert HorseshoeInUse();
        if (!horseshoeModule.isUseful(horseshoeId)) revert HorseshoeNotUseful();

        horseHasShoe[horseId][horseshoeId] = true;
        horseshoeEquipped[horseshoeId] = true;
        list.push(horseshoeId);

        emit HorseshoeEquipped(horseId, horseshoeId);
    }

    function _registerHorseshoeStats(
        uint256 horseshoeId,
        uint256 imgCategory,
        uint256 imgNumber,
        PerformanceStats calldata bonusStats,
        uint256 maxDurability,
        uint256 level,
        bool isPure
    ) internal {
        _requireHorseshoeModule();
        horseshoeModule.createHorseshoeStats(
            horseshoeId,
            imgCategory,
            imgNumber,
            bonusStats,
            maxDurability,
            level,
            isPure
        );
        emit HorseshoeStats(horseshoeId, imgCategory, imgNumber, bonusStats, maxDurability, level, isPure);
    }

    /// @notice Equip a horseshoe into one of the limited slots of the horse.
    function equipHorseshoe(uint256 horseId, uint256 horseshoeId) external {
        _requireHorseModule();
        _requireHorseshoeModule();
        _requireTokensConfigured();
        if (IERC721Minimal(speedHorsesToken).ownerOf(horseId) != msg.sender) revert NotHorseOwner();
        if (IERC721Minimal(horseshoesToken).ownerOf(horseshoeId) != msg.sender) revert NotHorseshoeOwner();
        if (horseHasShoe[horseId][horseshoeId]) revert AlreadyEquipped();
        if (horseshoeEquipped[horseshoeId]) revert HorseshoeInUse();

        uint256[] storage list = equippedHorseshoes[horseId];
        if (list.length >= MAX_SHOE_SLOTS) revert SlotsFull();

        // ensure horseshoe exists (will revert otherwise)
        horseshoeModule.getHorseshoe(horseshoeId);
        if (!horseshoeModule.isUseful(horseshoeId)) revert HorseshoeNotUseful();

        horseHasShoe[horseId][horseshoeId] = true;
        horseshoeEquipped[horseshoeId] = true;
        list.push(horseshoeId);

        emit HorseshoeEquipped(horseId, horseshoeId);
    }

    /// @notice Unequip a horseshoe. Blocked if the horse is registered for racing.
    function unequipHorseshoe(uint256 horseId, uint256 horseshoeId) external {
        _requireHorseModule();
        _requireTokensConfigured();
        if (IERC721Minimal(speedHorsesToken).ownerOf(horseId) != msg.sender) revert NotHorseOwner();
        if (!horseHasShoe[horseId][horseshoeId]) revert NotEquipped();

        // Block unequip while registered for racing
        if (isRegisteredForRacing(horseId)) revert HorseRegistered();

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
    function consumeEquippedDurability(uint256 horseId, uint256 lessPerShoe) external {
        _requireFixtureManager();
        _requireHorseshoeModule();
        if (lessPerShoe == 0) revert InvalidAmount();
        uint256[] storage list = equippedHorseshoes[horseId];
        if (list.length == 0) revert NoHorseshoesEquipped();

        // Iterate and consume durability on each equipped horseshoe.
        // This call will revert if SpeedH_Stats_Horseshoe' internal checks fail.
        for (uint256 i = 0; i < list.length; i++) {
            horseshoeModule.consume(list[i], lessPerShoe);
        }
    }

    // ---------------------------------------------------------------------
    // Views consumed by the ecosystem
    // ---------------------------------------------------------------------

    function getHorseStats(uint256 horseId) public view returns (PerformanceStats memory) {
        _requireHorseModule();
        SpeedH_Stats_Horse.HorseData memory data = horseModule.getHorse(horseId);
        return data.stats;
    }

    function getEquipmentBonus(uint256 horseId) public view returns (PerformanceStats memory totalBonus) {
        _requireHorseshoeModule();
        uint256[] storage list = equippedHorseshoes[horseId];
        totalBonus = PerformanceStats(0, 0, 0, 0, 0, 0, 0, 0);
        for (uint256 i = 0; i < list.length; i++) {
            SpeedH_Stats_Horseshoe.HorseshoeData memory shoe = horseshoeModule.getHorseshoe(list[i]);
            totalBonus = _addPerformance(totalBonus, shoe.bonusStats);
        }
    }

    function getRandomVisual(uint256 entropy) external view returns (uint256, uint256) {
        _requireHorseModule();
        return horseModule.getRandomVisual(entropy);
    }

    function getRandomHorseshoeVisual(uint256 entropy) external view returns (uint256, uint256) {
        _requireHorseshoeModule();
        return horseshoeModule.getRandomVisual(entropy);
    }

    function getPerformance(uint256 horseId) public view returns (PerformanceStats memory) {
        _requireHorseModule();
        _requireHorseshoeModule();
        PerformanceStats memory horseStats = getHorseStats(horseId);
        PerformanceStats memory equipment = getEquipmentBonus(horseId);
        return _addPerformance(horseStats, equipment);
    }

    function getHorsePerformance(uint256 horseId) public view returns (PerformanceStats memory) {
        return getHorseStats(horseId);
    }

    function getTotalPoints(uint256 horseId) public view returns (uint256) {
        _requireHorseModule();
        _requireHorseshoeModule();
        SpeedH_Stats_Horse.HorseData memory data = horseModule.getHorse(horseId);
        uint256 equipmentPoints = _sumStats(getEquipmentBonus(horseId));
        return data.totalPoints + equipmentPoints;
    }

    function getHorseTotalPoints(uint256 horseId) public view returns (uint256) {
        _requireHorseModule();
        SpeedH_Stats_Horse.HorseData memory data = horseModule.getHorse(horseId);
        return data.totalPoints;
    }

    function getLevel(uint256 horseId) public view returns (UFix6) {
        _requireHorseModule();
        _requireHorseshoeModule();
        uint256 total = getTotalPoints(horseId);
        if (total == 0) {
            return SpeedH_UFix6Lib.wrapRaw(0);
        }
        return SpeedH_UFix6Lib.log2_uint(total);
    }

    function refreshHorseCache(uint256 horseId) external {
        _requireHorseMinter();
        _requireHorseModule();
        _requireHorseshoeModule();
        PerformanceStats memory performance = getPerformance(horseId);
        horseModule.setCacheStats(horseId, performance);
    }

    function hasFinishedResting(uint256 horseId) public view returns (bool) {
        _requireHorseModule();
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
        _requireHorseModule();
        _requireHorseshoeModule();
        _requireHorseMetadata();
        SpeedH_Stats_Horse.HorseData memory data = horseModule.getHorse(horseId);
        PerformanceStats memory totalStats = getHorsePerformance(horseId);
        string memory categoryName = horseModule.getImgCategoryName(data.imgCategory);
        return horseMetadata.tokenURI(horseId, data, totalStats, getLevel(horseId), categoryName);
    }

    // returns all JSON metadata for the given horseshoeId
    function horseshoeTokenURI(uint256 horseshoeId) external view returns (string memory) {
        _requireHorseshoeModule();
        _requireHorseshoeMetadata();
        SpeedH_Stats_Horseshoe.HorseshoeData memory data = horseshoeModule.getHorseshoe(horseshoeId);
        string memory categoryName = horseshoeModule.getImgCategoryName(data.imgCategory);
        return horseshoeMetadata.tokenURI(horseshoeId, data, categoryName);
    }

    function isHorseshoeUseful(uint256 horseshoeId) external view returns (bool) {
        _requireHorseshoeModule();
        return horseshoeModule.isUseful(horseshoeId);
    }

    // ---------------------------------------------------------------------
    // Internal helpers
    // ---------------------------------------------------------------------

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
