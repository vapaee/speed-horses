// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { PerformanceStats } from "./SpeedH_StatsStructs.sol";
import { SpeedH_VisualsLib } from "./SpeedH_VisualsLib.sol";

/**
 * Title: SpeedH_Stats_Horse
 * Brief: Persistent storage for horses: visuals, base/assigned stats, points ledger and rest cooldown.
 *        Uses SpeedH_VisualsLib for category administration and random selection.
 */
contract SpeedH_Stats_Horse {
    using SpeedH_VisualsLib for SpeedH_VisualsLib.VisualSpace;

    // ---------------------------------------------------------------------
    // Roles
    // ---------------------------------------------------------------------
    address public owner;
    address public speedStats;
    string public version = "SpeedH_Stats_Horse-v1.0.0";

    modifier onlyOwner() {
        require(msg.sender == owner, "SpeedH_Stats_Horse: not owner");
        _;
    }

    modifier onlySpeedStats() {
        require(msg.sender == speedStats, "SpeedH_Stats_Horse: only controller");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function setSpeedStats(address controller) external onlyOwner {
        require(controller != address(0), "SpeedH_Stats_Horse: invalid controller");
        speedStats = controller;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "SpeedH_Stats_Horse: invalid owner");
        owner = newOwner;
    }

    // ---------------------------------------------------------------------
    // Horse data model
    // ---------------------------------------------------------------------
    struct HorseData {
        uint256 imgCategory;
        uint256 imgNumber;
        PerformanceStats baseStats;
        PerformanceStats assignedStats;
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
        PerformanceStats calldata baseStats
    ) external onlySpeedStats {
        HorseData storage h = horses[horseId];
        require(!h.exists, "SpeedH_Stats_Horse: horse exists");

        h.exists = true;
        h.imgCategory = imgCategory;
        h.imgNumber = imgNumber;
        h.baseStats = baseStats;
        h.assignedStats = PerformanceStats(0, 0, 0, 0, 0, 0, 0, 0);
        h.totalPoints = _sumStats(baseStats);
        h.unassignedPoints = 0;
        h.restFinish = 0;
    }

    function addPoints(uint256 horseId, uint256 points) external onlySpeedStats {
        HorseData storage h = horses[horseId];
        require(h.exists, "SpeedH_Stats_Horse: unknown horse");
        h.totalPoints += points;
        h.unassignedPoints += points;
    }

    function consumeUnassigned(uint256 horseId, uint256 points) external onlySpeedStats {
        HorseData storage h = horses[horseId];
        require(h.exists, "SpeedH_Stats_Horse: unknown horse");
        require(h.unassignedPoints >= points, "SpeedH_Stats_Horse: not enough points");
        h.unassignedPoints -= points;
    }

    function setAssignedStats(uint256 horseId, PerformanceStats calldata stats) external onlySpeedStats {
        HorseData storage h = horses[horseId];
        require(h.exists, "SpeedH_Stats_Horse: unknown horse");
        h.assignedStats = stats;
    }

    function setRestFinish(uint256 horseId, uint256 restFinish) external onlySpeedStats {
        HorseData storage h = horses[horseId];
        require(h.exists, "SpeedH_Stats_Horse: unknown horse");
        h.restFinish = restFinish;
    }

    // ---------------------------------------------------------------------
    // Views
    // ---------------------------------------------------------------------

    function getHorse(uint256 horseId) external view returns (HorseData memory) {
        HorseData memory h = horses[horseId];
        require(h.exists, "SpeedH_Stats_Horse: unknown horse");
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
