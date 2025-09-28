// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { PerformanceStats } from "../StatsStructs.sol";

/// @title HorseStatsModule
/// @notice Storage contract that keeps track of every horse and its raw statistics.
/// @dev This module is meant to be driven by SpeedStats and therefore only exposes
///      mutating functions to the controller contract. Read helpers are left public
///      so external systems can inspect the horse state off-chain when required.
contract HorseStatsModule {
    // ---------------------------------------------------------------------
    // Roles
    // ---------------------------------------------------------------------
    address public owner;
    address public speedStats;

    modifier onlyOwner() {
        require(msg.sender == owner, "HorseStatsModule: not owner");
        _;
    }

    modifier onlySpeedStats() {
        require(msg.sender == speedStats, "HorseStatsModule: only controller");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function setSpeedStats(address controller) external onlyOwner {
        require(controller != address(0), "HorseStatsModule: invalid controller");
        speedStats = controller;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "HorseStatsModule: invalid owner");
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
    // Visual categories
    // ---------------------------------------------------------------------
    struct ImgCategoryData {
        string name;
        uint256 maxImgNumber;
        bool exists;
    }

    mapping(uint256 => ImgCategoryData) public imgCategories;
    uint256[] private imgCategoryIds;

    // ---------------------------------------------------------------------
    // Category administration
    // ---------------------------------------------------------------------

    function setImgCategory(uint256 imgCategory, string calldata name, uint256 maxImgNumber)
        external
        onlySpeedStats
    {
        ImgCategoryData storage data = imgCategories[imgCategory];

        if (!data.exists) {
            imgCategoryIds.push(imgCategory);
            data.exists = true;
        }

        data.name = name;
        data.maxImgNumber = maxImgNumber;
    }

    function getImgCategoryIds() external view returns (uint256[] memory) {
        return imgCategoryIds;
    }

    // ---------------------------------------------------------------------
    // Horse mutations (only controller)
    // ---------------------------------------------------------------------

    function createHorse(
        uint256 horseId,
        uint256 imgCategory,
        uint256 imgNumber,
        PerformanceStats calldata baseStats
    ) external onlySpeedStats {
        HorseData storage h = horses[horseId];
        require(!h.exists, "HorseStatsModule: horse exists");

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
        require(h.exists, "HorseStatsModule: unknown horse");
        h.totalPoints += points;
        h.unassignedPoints += points;
    }

    function consumeUnassigned(uint256 horseId, uint256 points) external onlySpeedStats {
        HorseData storage h = horses[horseId];
        require(h.exists, "HorseStatsModule: unknown horse");
        require(h.unassignedPoints >= points, "HorseStatsModule: not enough points");
        h.unassignedPoints -= points;
    }

    function setAssignedStats(uint256 horseId, PerformanceStats calldata stats) external onlySpeedStats {
        HorseData storage h = horses[horseId];
        require(h.exists, "HorseStatsModule: unknown horse");
        h.assignedStats = stats;
    }

    function setRestFinish(uint256 horseId, uint256 restFinish) external onlySpeedStats {
        HorseData storage h = horses[horseId];
        require(h.exists, "HorseStatsModule: unknown horse");
        h.restFinish = restFinish;
    }

    // ---------------------------------------------------------------------
    // Views
    // ---------------------------------------------------------------------

    function getHorse(uint256 horseId) external view returns (HorseData memory) {
        HorseData memory h = horses[horseId];
        require(h.exists, "HorseStatsModule: unknown horse");
        return h;
    }

    function getRandomVisual(uint256 entropy) external view onlySpeedStats returns (uint256, uint256) {
        require(imgCategoryIds.length > 0, "HorseStatsModule: no categories");

        uint256 validCategories = 0;
        uint256 length = imgCategoryIds.length;
        for (uint256 i = 0; i < length; i++) {
            ImgCategoryData storage data = imgCategories[imgCategoryIds[i]];
            if (data.exists && data.maxImgNumber > 0) {
                validCategories++;
            }
        }

        require(validCategories > 0, "HorseStatsModule: categories empty");

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

        require(selectedCategory != type(uint256).max, "HorseStatsModule: invalid selection");

        ImgCategoryData storage chosen = imgCategories[selectedCategory];
        uint256 numberSeed = uint256(keccak256(abi.encodePacked(categorySeed, entropy, block.number)));
        uint256 selectedNumber = (numberSeed % chosen.maxImgNumber) + 1;

        return (selectedCategory, selectedNumber);
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
