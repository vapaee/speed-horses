// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { PerformanceStats } from "./SpeedH_StatsStructs.sol";
import { SpeedH_VisualsLib } from "./SpeedH_VisualsLib.sol";

/**
 * Title: SpeedH_Stats_Horseshoe
 * Brief: Lifecycle and storage of horseshoes: bonus stats, durability, and visuals.
 *        Uses SpeedH_VisualsLib for category administration and random selection.
 */
contract SpeedH_Stats_Horseshoe {
    using SpeedH_VisualsLib for SpeedH_VisualsLib.VisualSpace;

    address public owner;
    address public speedStats;
    string public version = "SpeedH_Stats_Horseshoe-v1.0.1";

    modifier onlyOwner() {
        require(msg.sender == owner, "SpeedH_Stats_Horseshoe: not owner");
        _;
    }

    modifier onlySpeedStats() {
        require(msg.sender == speedStats, "SpeedH_Stats_Horseshoe: only controller");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function setSpeedStats(address controller) external onlyOwner {
        require(controller != address(0), "SpeedH_Stats_Horseshoe: invalid controller");
        speedStats = controller;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "SpeedH_Stats_Horseshoe: invalid owner");
        owner = newOwner;
    }

    struct HorseshoeData {
        // visuals
        uint256 imgCategory;
        uint256 imgNumber;
        // mechanics
        PerformanceStats bonusStats;
        uint256 maxDurability;
        uint256 durabilityUsed;
        uint256 level;
        bool isPure;
        bool exists;
    }

    mapping(uint256 => HorseshoeData) private horseshoes;

    // ---------------------------------------------------------------------
    // Visuals (for horseshoes) via SpeedH_VisualsLib
    // ---------------------------------------------------------------------
    SpeedH_VisualsLib.VisualSpace private shoeVisuals;

    /// @notice Adds/updates image categories for horseshoes.
    function setImgCategory(uint256 imgCategory, string calldata name, uint256 maxImgNumber)
        external
        onlySpeedStats
    {
        shoeVisuals.setImgCategory(imgCategory, name, maxImgNumber);
    }

    function getImgCategoryIds() external view returns (uint256[] memory) {
        return shoeVisuals.getImgCategoryIds();
    }

    function getImgCategoryName(uint256 imgCategory) external view returns (string memory) {
        SpeedH_VisualsLib.ImgCategoryData storage data = shoeVisuals.imgCategories[imgCategory];
        return data.name;
    }

    /// @notice Random visual usable by the controller (same signature as in SpeedH_Stats_Horse).
    function getRandomVisual(uint256 entropy) external view onlySpeedStats returns (uint256, uint256) {
        return shoeVisuals.getRandomVisual(entropy);
    }

    // ---------------------------------------------------------------------
    // Lifecycle
    // ---------------------------------------------------------------------

    function createHorseshoeStats(
        uint256 horseshoeId,
        uint256 imgCategory,
        uint256 imgNumber,
        PerformanceStats calldata bonusStats,
        uint256 maxDurability,
        uint256 level,
        bool isPure
    ) external onlySpeedStats {
        HorseshoeData storage data = horseshoes[horseshoeId];
        require(!data.exists, "SpeedH_Stats_Horseshoe: horseshoe exists");
        require(maxDurability > 0, "SpeedH_Stats_Horseshoe: invalid durability");

        SpeedH_VisualsLib.ImgCategoryData storage cat = shoeVisuals.imgCategories[imgCategory];
        require(cat.exists && imgNumber >= 1 && imgNumber <= cat.maxImgNumber, "SpeedH_Stats_Horseshoe: invalid image");

        data.imgCategory = imgCategory;
        data.imgNumber = imgNumber;

        data.bonusStats = bonusStats;
        data.maxDurability = maxDurability;
        data.durabilityUsed = maxDurability; // as per your current semantics
        data.level = level;
        data.isPure = isPure;
        data.exists = true;
    }

    function restore(uint256 horseshoeId) external onlySpeedStats {
        HorseshoeData storage data = horseshoes[horseshoeId];
        require(data.exists, "SpeedH_Stats_Horseshoe: unknown horseshoe");
        data.durabilityUsed = data.maxDurability;
    }

    function consume(uint256 horseshoeId, uint256 less) external onlySpeedStats {
        HorseshoeData storage data = horseshoes[horseshoeId];
        require(data.exists, "SpeedH_Stats_Horseshoe: unknown horseshoe");
        require(less > data.durabilityUsed, "SpeedH_Stats_Horseshoe: insufficient durability");
        data.durabilityUsed = data.durabilityUsed - less;
    }

    function getHorseshoe(uint256 horseshoeId) external view returns (HorseshoeData memory) {
        HorseshoeData memory data = horseshoes[horseshoeId];
        require(data.exists, "SpeedH_Stats_Horseshoe: unknown horseshoe");
        return data;
    }
}
