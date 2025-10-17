// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { PerformanceStats } from "./SpeedH_StatsStructs.sol";
import { SpeedH_VisualsLib } from "./SpeedH_VisualsLib.sol";

error NotOwner();
error NotController();
error InvalidController();
error InvalidOwner();
error HorseshoeAlreadyExists();
error InvalidDurability();
error InvalidImage();
error HorseshoeNotFound();
error InsufficientDurability();

/**
 * Title: SpeedH_Stats_Horseshoe
 * Brief: Lifecycle and storage of horseshoes: bonus stats, durability, and visuals.
 *        Uses SpeedH_VisualsLib for category administration and random selection.
 */
contract SpeedH_Stats_Horseshoe {
    using SpeedH_VisualsLib for SpeedH_VisualsLib.VisualSpace;

    address public owner;
    address public _contractStats;
    string public version = "SpeedH_Stats_Horseshoe-v1.0.0";

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

    struct HorseshoeData {
        // visuals
        uint256 imgCategory;
        uint256 imgNumber;
        // mechanics
        PerformanceStats bonusStats;
        uint256 maxDurability;
        uint256 durabilityRemaining;
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
        if (data.exists) revert HorseshoeAlreadyExists();
        if (maxDurability == 0) revert InvalidDurability();

        SpeedH_VisualsLib.ImgCategoryData storage cat = shoeVisuals.imgCategories[imgCategory];
        if (!(cat.exists && imgNumber >= 1 && imgNumber <= cat.maxImgNumber)) revert InvalidImage();

        data.imgCategory = imgCategory;
        data.imgNumber = imgNumber;

        data.bonusStats = bonusStats;
        data.maxDurability = maxDurability;
        data.durabilityRemaining = maxDurability;
        data.level = level;
        data.isPure = isPure;
        data.exists = true;
    }

    function restore(uint256 horseshoeId) external onlySpeedStats {
        HorseshoeData storage data = horseshoes[horseshoeId];
        if (!data.exists) revert HorseshoeNotFound();
        data.durabilityRemaining = data.maxDurability;
    }

    function consume(uint256 horseshoeId, uint256 less) external onlySpeedStats {
        HorseshoeData storage data = horseshoes[horseshoeId];
        if (!data.exists) revert HorseshoeNotFound();
        if (less > data.durabilityRemaining) revert InsufficientDurability();
        data.durabilityRemaining = data.durabilityRemaining - less;
    }

    function getHorseshoe(uint256 horseshoeId) external view returns (HorseshoeData memory) {
        HorseshoeData memory data = horseshoes[horseshoeId];
        if (!data.exists) revert HorseshoeNotFound();
        return data;
    }

    function isUseful(uint256 horseshoeId) external view returns (bool) {
        HorseshoeData memory data = horseshoes[horseshoeId];
        if (!data.exists) revert HorseshoeNotFound();
        return data.durabilityRemaining > 0;
    }
}
