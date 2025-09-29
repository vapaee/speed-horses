// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { PerformanceStats } from "./StatsStructs.sol";
import { VisualsLib } from "./VisualsLib.sol";

/**
 * Title: HorseshoeStats
 * Brief: Lifecycle and storage of horseshoes: bonus stats, durability, and visuals.
 *        Uses VisualsLib for category administration and random selection.
 */
contract HorseshoeStats {
    using VisualsLib for VisualsLib.VisualSpace;

    address public owner;
    address public speedStats;

    modifier onlyOwner() {
        require(msg.sender == owner, "HorseshoeStats: not owner");
        _;
    }

    modifier onlySpeedStats() {
        require(msg.sender == speedStats, "HorseshoeStats: only controller");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function setSpeedStats(address controller) external onlyOwner {
        require(controller != address(0), "HorseshoeStats: invalid controller");
        speedStats = controller;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "HorseshoeStats: invalid owner");
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
    }

    mapping(uint256 => HorseshoeData) private horseshoes;

    // ---------------------------------------------------------------------
    // Visuals (for horseshoes) via VisualsLib
    // ---------------------------------------------------------------------
    VisualsLib.VisualSpace private shoeVisuals;

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

    /// @notice Random visual usable by the controller (same signature as in HorseStats).
    function getRandomVisual(uint256 entropy) external view onlySpeedStats returns (uint256, uint256) {
        return shoeVisuals.getRandomVisual(entropy);
    }

    // ---------------------------------------------------------------------
    // Lifecycle
    // ---------------------------------------------------------------------

    function createHorseshoe(
        uint256 horseshoeId,
        PerformanceStats calldata bonusStats,
        uint256 maxDurability
    ) external onlySpeedStats {
        HorseshoeData storage data = horseshoes[horseshoeId];
        require(data.maxDurability == 0, "HorseshoeStats: horseshoe exists");
        require(maxDurability > 0, "HorseshoeStats: invalid durability");

        // visuals will be set later via setHorseshoeImage (keeps signature stable)
        data.imgCategory = 0;
        data.imgNumber = 0;

        data.bonusStats = bonusStats;
        data.maxDurability = maxDurability;
        data.durabilityUsed = maxDurability; // as per your current semantics
    }

    /// @notice Sets the image for a given horseshoe (restricted to controller).
    function setHorseshoeImage(
        uint256 horseshoeId,
        uint256 imgCategory,
        uint256 imgNumber
    ) external onlySpeedStats {
        HorseshoeData storage data = horseshoes[horseshoeId];
        require(data.maxDurability > 0, "HorseshoeStats: unknown horseshoe");
        // Optional guards: ensure category exists and number is within range
        VisualsLib.ImgCategoryData storage cat = shoeVisuals.imgCategories[imgCategory];
        require(cat.exists && imgNumber >= 1 && imgNumber <= cat.maxImgNumber, "HorseshoeStats: invalid image");
        data.imgCategory = imgCategory;
        data.imgNumber = imgNumber;
    }

    function restore(uint256 horseshoeId) external onlySpeedStats {
        HorseshoeData storage data = horseshoes[horseshoeId];
        require(data.maxDurability > 0, "HorseshoeStats: unknown horseshoe");
        data.durabilityUsed = data.maxDurability;
    }

    function consume(uint256 horseshoeId, uint256 less) external onlySpeedStats {
        HorseshoeData storage data = horseshoes[horseshoeId];
        require(data.maxDurability > 0, "HorseshoeStats: unknown horseshoe");
        require(less > data.durabilityUsed, "HorseshoeStats: insufficient durability");
        data.durabilityUsed = data.durabilityUsed - less;
    }

    function getHorseshoe(uint256 horseshoeId) external view returns (HorseshoeData memory) {
        HorseshoeData memory data = horseshoes[horseshoeId];
        require(data.maxDurability > 0, "HorseshoeStats: unknown horseshoe");
        return data;
    }
}
