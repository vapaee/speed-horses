// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * Título: SpeedH_StatsStructs
 * Brief: Definiciones de estructuras de datos compartidas que encapsulan tanto las estadísticas de rendimiento como los atributos de enfriamiento utilizados por múltiples contratos del juego para describir caballos y sus progresos.
 * API: proporciona los structs `PerformanceStats` y `CooldownStats`, que agrupan los campos necesarios para procesos de minteo, asignación de puntos, cálculo de niveles y descansos. Estos tipos se importan en los demás contratos para mantener una interfaz coherente en cada etapa del ciclo de vida del caballo.
 */
struct PerformanceStats {
    uint256 power;
    uint256 acceleration;
    uint256 stamina;
    uint256 minSpeed;
    uint256 maxSpeed;
    uint256 luck;
    uint256 curveBonus;
    uint256 straightBonus;
}

/// @notice Cooldown reduction attributes for each horse
struct CooldownStats {
    uint256 resting;
}
