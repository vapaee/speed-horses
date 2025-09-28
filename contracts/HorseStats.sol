// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { PerformanceStats } from "./StatsStructs.sol";

/**
 * Título: HorseStats
 * Brief: Registro integral de caballos que consolida atributos visuales, estadísticas base y puntos asignables para cada NFT,
 *         controlando además permisos administrativos y de controlador.
 * API: expone operaciones restringidas al coordinador (`createHorse`, `addPoints`, `consumeUnassigned`, `setAssignedStats`,
 *       `setRestFinish`, `setImgCategory`) junto a vistas públicas (`getHorse`, `getImgCategoryIds`, `getRandomVisual`) que
 *       devuelven el estado completo y utilidades de selección visual.
 */
contract HorseStats {
    // ---------------------------------------------------------------------
    // Roles
    // ---------------------------------------------------------------------
    address public owner;
    address public speedStats;

    modifier onlyOwner() {
        require(msg.sender == owner, "HorseStats: not owner");
        _;
    }

    modifier onlySpeedStats() {
        require(msg.sender == speedStats, "HorseStats: only controller");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function setSpeedStats(address controller) external onlyOwner {
        require(controller != address(0), "HorseStats: invalid controller");
        speedStats = controller;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "HorseStats: invalid owner");
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
        require(!h.exists, "HorseStats: horse exists");

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
        require(h.exists, "HorseStats: unknown horse");
        h.totalPoints += points;
        h.unassignedPoints += points;
    }

    function consumeUnassigned(uint256 horseId, uint256 points) external onlySpeedStats {
        HorseData storage h = horses[horseId];
        require(h.exists, "HorseStats: unknown horse");
        require(h.unassignedPoints >= points, "HorseStats: not enough points");
        h.unassignedPoints -= points;
    }

    function setAssignedStats(uint256 horseId, PerformanceStats calldata stats) external onlySpeedStats {
        HorseData storage h = horses[horseId];
        require(h.exists, "HorseStats: unknown horse");
        h.assignedStats = stats;
    }

    function setRestFinish(uint256 horseId, uint256 restFinish) external onlySpeedStats {
        HorseData storage h = horses[horseId];
        require(h.exists, "HorseStats: unknown horse");
        h.restFinish = restFinish;
    }

    // ---------------------------------------------------------------------
    // Views
    // ---------------------------------------------------------------------

    function getHorse(uint256 horseId) external view returns (HorseData memory) {
        HorseData memory h = horses[horseId];
        require(h.exists, "HorseStats: unknown horse");
        return h;
    }

    function getRandomVisual(uint256 entropy) external view onlySpeedStats returns (uint256, uint256) {
        require(imgCategoryIds.length > 0, "HorseStats: no categories");

        uint256 validCategories = 0;
        uint256 length = imgCategoryIds.length;
        for (uint256 i = 0; i < length; i++) {
            ImgCategoryData storage data = imgCategories[imgCategoryIds[i]];
            if (data.exists && data.maxImgNumber > 0) {
                validCategories++;
            }
        }

        require(validCategories > 0, "HorseStats: categories empty");

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

        require(selectedCategory != type(uint256).max, "HorseStats: invalid selection");

        ImgCategoryData storage chosen = imgCategories[selectedCategory];
        uint256 numberSeed = uint256(keccak256(abi.encodePacked(categorySeed, entropy, block.number)));
        uint256 selectedNumber = (numberSeed % chosen.maxImgNumber) + 1;

        return (selectedCategory, selectedNumber);
    }

    // ---------------------------------------------------------------------
    // Internal helpers
    // ---------------------------------------------------------------------

    function _sumStats(PerformanceStats memory stats) internal pure returns (uint256) {
        return stats.power + stats.acceleration + stats.stamina + stats.minSpeed + stats.maxSpeed + stats.luck
            + stats.curveBonus + stats.straightBonus;
    }
}
