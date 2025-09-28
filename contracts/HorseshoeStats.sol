// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { PerformanceStats } from "./StatsStructs.sol";

/**
 * Título: HorseshoeStats
 * Brief: Gestión del ciclo de vida de cada herradura incluyendo estadísticas de bonificación y durabilidad,
 *         con salvaguardas de permisos para administración y controlador.
 * API: permite al coordinador registrar (`createHorseshoe`), aumentar durabilidad máxima (`addDurability`) y consumir durabilidad (`consumeDurability`),
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
    }

    mapping(uint256 => HorseshoeData) private horseshoes;

    function createHorseshoe(
        uint256 horseshoeId,
        PerformanceStats calldata bonusStats,
        uint256 maxDurability
    ) external onlySpeedStats {
        HorseshoeData storage data = horseshoes[horseshoeId];
        require(data.maxDurability == 0, "HorseshoeStats: horseshoe exists");
        require(maxDurability > 0, "HorseshoeStats: invalid durability");

        data.bonusStats = bonusStats;
        data.maxDurability = maxDurability;
        data.durabilityUsed = 0;
    }

    function addDurability(uint256 horseshoeId, uint256 plus) external onlySpeedStats {
        HorseshoeData storage data = horseshoes[horseshoeId];
        require(data.maxDurability > 0, "HorseshoeStats: unknown horseshoe");
        data.maxDurability += plus;
        if (data.durabilityUsed > data.maxDurability) {
            data.durabilityUsed = data.maxDurability;
        }
    }

    function consumeDurability(uint256 horseshoeId, uint256 less) external onlySpeedStats {
        HorseshoeData storage data = horseshoes[horseshoeId];
        require(data.maxDurability > 0, "HorseshoeStats: unknown horseshoe");
        data.durabilityUsed += less;
        if (data.durabilityUsed > data.maxDurability) {
            data.durabilityUsed = data.maxDurability;
        }
    }

    function getHorseshoe(uint256 horseshoeId) external view returns (HorseshoeData memory) {
        HorseshoeData memory data = horseshoes[horseshoeId];
        require(data.maxDurability > 0, "HorseshoeStats: unknown horseshoe");
        return data;
    }
}
