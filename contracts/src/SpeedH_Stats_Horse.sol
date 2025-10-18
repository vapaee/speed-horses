// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { PerformanceStats } from "./SpeedH_StatsStructs.sol";
import { SpeedH_VisualsLib } from "./SpeedH_VisualsLib.sol";

error NotOwner();
error NotController();
error InvalidController();
error InvalidOwner();
error HorseAlreadyExists();
error InvalidImage();
error HorseNotFound();
error InsufficientPoints();

/**
 * Title: SpeedH_Stats_Horse
 * Brief: Persistent storage for horses: visuals, aggregated stats, points ledger and rest cooldown.
 *        Uses SpeedH_VisualsLib for category administration and random selection.
 */
contract SpeedH_Stats_Horse {
    using SpeedH_VisualsLib for SpeedH_VisualsLib.VisualSpace;

    // ---------------------------------------------------------------------
    // Roles
    // ---------------------------------------------------------------------
    address public owner;
    address public _contractStats;
    string public version = "SpeedH_Stats_Horse-v1.0.0";

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlySpeedStats() {
        if (msg.sender != _contractStats) revert NotController();
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function setContractStats(address contractStats) external onlyOwner {
        if (contractStats == address(0)) revert InvalidController();
        _contractStats = contractStats;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert InvalidOwner();
        owner = newOwner;
    }

    // ---------------------------------------------------------------------
    // Horse data model
    // ---------------------------------------------------------------------
    struct HorseData {
        uint256 imgCategory;
        uint256 imgNumber;
        PerformanceStats stats;
        PerformanceStats cacheStats;
        uint256 totalPoints;
        uint256 unassignedPoints;
        uint256 restFinish;
        bool exists;
    }

    mapping(uint256 => HorseData) private horses;

    // ---------------------------------------------------------------------
    // Visuals (for horses) via SpeedH_VisualsLib
    // ---------------------------------------------------------------------
    SpeedH_VisualsLib.VisualSpace private horseVisuals;

    // Category administration (proxied to library)
    function setImgCategory(uint256 imgCategory, string calldata name, uint256 maxImgNumber)
        external
        onlySpeedStats
    {
        horseVisuals.setImgCategory(imgCategory, name, maxImgNumber);
    }

    function getImgCategoryIds() external view returns (uint256[] memory) {
        return horseVisuals.getImgCategoryIds();
    }

    function getImgCategoryName(uint256 imgCategory) external view returns (string memory) {
        SpeedH_VisualsLib.ImgCategoryData storage data = horseVisuals.imgCategories[imgCategory];
        return data.name;
    }

    // ---------------------------------------------------------------------
    // Horse mutations (only controller)
    // ---------------------------------------------------------------------

    function createHorseStats(
        uint256 horseId,
        uint256 imgCategory,
        uint256 imgNumber,
        PerformanceStats calldata stats
    ) external onlySpeedStats {
        HorseData storage h = horses[horseId];
        if (h.exists) revert HorseAlreadyExists();

        SpeedH_VisualsLib.ImgCategoryData storage cat = horseVisuals.imgCategories[imgCategory];
        if (!(cat.exists && imgNumber >= 1 && imgNumber <= cat.maxImgNumber)) revert InvalidImage();

        h.exists = true;
        h.imgCategory = imgCategory;
        h.imgNumber = imgNumber;
        h.stats = stats;
        h.cacheStats = PerformanceStats(0, 0, 0, 0, 0, 0, 0, 0);
        h.totalPoints = _sumStats(stats);
        h.unassignedPoints = 0;
        h.restFinish = 0;
    }

    function addPoints(uint256 horseId, uint256 points) external onlySpeedStats {
        HorseData storage h = horses[horseId];
        if (!h.exists) revert HorseNotFound();
        h.totalPoints += points;
        h.unassignedPoints += points;
    }

    function consumeUnassigned(uint256 horseId, uint256 points) external onlySpeedStats {
        HorseData storage h = horses[horseId];
        if (!h.exists) revert HorseNotFound();
        if (h.unassignedPoints < points) revert InsufficientPoints();
        h.unassignedPoints -= points;
    }

    function setStats(uint256 horseId, PerformanceStats calldata stats) external onlySpeedStats {
        HorseData storage h = horses[horseId];
        if (!h.exists) revert HorseNotFound();
        h.stats = stats;
    }

    function setCacheStats(uint256 horseId, PerformanceStats calldata stats) external onlySpeedStats {
        HorseData storage h = horses[horseId];
        if (!h.exists) revert HorseNotFound();
        h.cacheStats = stats;
    }

    function setRestFinish(uint256 horseId, uint256 restFinish) external onlySpeedStats {
        HorseData storage h = horses[horseId];
        if (!h.exists) revert HorseNotFound();
        h.restFinish = restFinish;
    }

    // ---------------------------------------------------------------------
    // Views
    // ---------------------------------------------------------------------

    function getHorse(uint256 horseId) external view returns (HorseData memory) {
        HorseData memory h = horses[horseId];
        if (!h.exists) revert HorseNotFound();
        return h;
    }

    /// @notice Generic random visual using the shared library (restricted to controller).
    function getRandomVisual(uint256 entropy) external view onlySpeedStats returns (uint256, uint256) {
        return horseVisuals.getRandomVisual(entropy);
    }

    // ---------------------------------------------------------------------
    // Internal helpers
    // ---------------------------------------------------------------------

    function _sumStats(PerformanceStats memory stats) internal pure returns (uint256) {
        return stats.power + stats.acceleration + stats.stamina + stats.minSpeed + stats.maxSpeed + stats.luck
            + stats.curveBonus + stats.straightBonus;
    }
}
