// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { PerformanceStats } from "./StatsStructs.sol";

/**
 * Título: HorseshoeStats
 * Brief: Gestión del ciclo de vida de cada herradura incluyendo estadísticas de bonificación, durabilidad y ajustes permitidos,
 *         con salvaguardas de permisos para administración y controlador.
 * API: permite al coordinador registrar (`createHorseshoe`), consumir durabilidad (`markUsage`) y registrar ajustes (`registerAdjustment`),
 *       mientras expone lecturas públicas del estado completo mediante `getHorseshoe`.
 */
contract HorseshoeStats {
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
        PerformanceStats bonusStats;
        uint256 maxDurability;
        uint256 durabilityUsed;
        uint256 maxAdjustments;
        uint256 adjustmentsUsed;
        bool exists;
    }

    mapping(uint256 => HorseshoeData) private horseshoes;

    function createHorseshoe(
        uint256 horseshoeId,
        PerformanceStats calldata bonusStats,
        uint256 maxDurability,
        uint256 maxAdjustments
    ) external onlySpeedStats {
        HorseshoeData storage data = horseshoes[horseshoeId];
        require(!data.exists, "HorseshoeStats: horseshoe exists");

        data.exists = true;
        data.bonusStats = bonusStats;
        data.maxDurability = maxDurability;
        data.maxAdjustments = maxAdjustments;
        data.durabilityUsed = 0;
        data.adjustmentsUsed = 0;
    }

    function markUsage(uint256 horseshoeId, uint256 durabilityUsed) external onlySpeedStats {
        HorseshoeData storage data = horseshoes[horseshoeId];
        require(data.exists, "HorseshoeStats: unknown horseshoe");
        data.durabilityUsed += durabilityUsed;
        if (data.durabilityUsed > data.maxDurability) {
            data.durabilityUsed = data.maxDurability;
        }
    }

    function registerAdjustment(uint256 horseshoeId, uint256 adjustments) external onlySpeedStats {
        HorseshoeData storage data = horseshoes[horseshoeId];
        require(data.exists, "HorseshoeStats: unknown horseshoe");
        data.adjustmentsUsed += adjustments;
        if (data.adjustmentsUsed > data.maxAdjustments) {
            data.adjustmentsUsed = data.maxAdjustments;
        }
    }

    function getHorseshoe(uint256 horseshoeId) external view returns (HorseshoeData memory) {
        HorseshoeData memory data = horseshoes[horseshoeId];
        require(data.exists, "HorseshoeStats: unknown horseshoe");
        return data;
    }
}
