// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { PerformanceStats, CooldownStats } from "./StatsStructs.sol";

interface IHorseStats {
    function createHorse(uint256 horseId, uint256 imgCategory, uint256 imgNumber, PerformanceStats calldata baseStats) external;
    function getRandomVisual(uint256 entropy) external view returns (uint256 imgCategory, uint256 imgNumber);
}

interface ISpeedHorses {
    function mint(address to, uint256 horseId) external;
}

/**
 * Título: HorseMinter
 * Brief: Coordinador del proceso de creación de caballos que cobra tarifas en TLOS y genera las combinaciones iniciales de categorías de imagen y estadísticas para cada jugador antes de acuñar el NFT y registrar sus atributos definitivos. Gestiona el flujo de construcción incremental, contabiliza los paquetes de puntos extra adquiridos y comunica los resultados al contrato de estadísticas y al ERC-721 del juego.
 * API: ofrece funciones públicas que modelan el proceso de minteo en etapas (`startHorseMint`, `randomizeHorse`, `buyExtraPoints`, `claimHorse`), cada una avanzando el estado del caballo pendiente y validando pagos y límites; incluye utilidades pseudoaleatorias para categorías de imagen y estadísticas (`_randomStats`, `_randomVisual`, `_randomize`) utilizadas durante dicho proceso. El administrador conecta dependencias y gestiona fondos mediante `setHorseStats`, `setSpeedHorses` y `withdrawTLOS`, completando así el circuito operativo del minter.
 */
contract HorseMinter {
    string public version = "HorseMinter-v1.0.0";

    // ---------------------------------------------------------------------
    // Contract References
    // ---------------------------------------------------------------------
    address public admin;
    IHorseStats public horseStats;
    ISpeedHorses public speedHorses;

    // ---------------------------------------------------------------------
    // Constants
    // ---------------------------------------------------------------------
    uint256 public constant BASE_CREATION_COST = 600 ether; // en TLOS
    uint256 public constant RANDOMIZE_COST = 100 ether;     // en TLOS
    uint256 public constant EXTRA_POINTS_COST = 200 ether;  // en TLOS
    uint256 public constant MAX_EXTRA_PACKAGES = 4;
    uint256 public constant BASE_INITIAL_POINTS = 60;
    uint256 public constant EXTRA_POINTS_PER_PACKAGE = 10;

    uint256 public nextHorseId;

    struct HorseBuild {
        uint256 imgCategory;
        uint256 imgNumber;
        PerformanceStats baseStats;
        uint256 totalPoints;
        uint8 extraPackagesBought;
    }

    mapping(address => HorseBuild) public pendingHorse;

    modifier onlyAdmin() {
        require(msg.sender == admin, 'Not admin');
        _;
    }

    constructor() {
        admin = msg.sender;
        nextHorseId = 1;
    }

    function startHorseMint() external payable {
        require(pendingHorse[msg.sender].totalPoints == 0, 'Already minting a horse');
        require(msg.value == BASE_CREATION_COST, 'Incorrect TLOS amount');

        HorseBuild memory newHorse = _randomize(BASE_INITIAL_POINTS, false, false);

        pendingHorse[msg.sender] = newHorse;
    }

    function randomizeHorse(bool keepImage, bool keepStats) external payable {
        require(!(keepImage && keepStats), 'Cannot fix both image and stats');

        HorseBuild storage build = pendingHorse[msg.sender];
        require(build.totalPoints != 0, 'No horse to randomize');
        require(msg.value == RANDOMIZE_COST, 'Incorrect TLOS amount');

        pendingHorse[msg.sender] = _randomize(build.totalPoints, keepImage, keepStats);
    }

    function buyExtraPoints() external payable {
        HorseBuild storage build = pendingHorse[msg.sender];
        require(build.totalPoints != 0, 'No horse to upgrade');
        require(build.extraPackagesBought < MAX_EXTRA_PACKAGES, 'Max extra points reached');
        require(msg.value == EXTRA_POINTS_COST, 'Incorrect TLOS amount');

        build.extraPackagesBought += 1;
        build.totalPoints = BASE_INITIAL_POINTS + (build.extraPackagesBought * EXTRA_POINTS_PER_PACKAGE);
        build.baseStats = _randomStats(build.totalPoints);
    }

    function claimHorse() external {
        HorseBuild storage build = pendingHorse[msg.sender];
        require(build.totalPoints != 0, 'No horse to claim');

        uint256 horseId = nextHorseId++;
        speedHorses.mint(msg.sender, horseId);
        horseStats.createHorse(horseId, build.imgCategory, build.imgNumber, build.baseStats);

        delete pendingHorse[msg.sender];
    }

    // ----------------------------------------------------
    // Random Helpers (pseudo-random, no para mainnet)
    // ----------------------------------------------------

    function _randomStats(uint256 totalPoints) public view returns (PerformanceStats memory) {
        uint256[8] memory distribution;
        uint256 remaining = totalPoints;

        // El algoritmo debe ser el siguiente:
        // Se itera indefinidas veces mientras queden puntos por distribuir.
        // el índice i se reinicia a 0 cuando llega a 7.
        // En cada iteración, se genera un número aleatorio entre 1 y 5.
        // al final de cada iteración se resta el número generado a remaining.
        // Si remaining es 0, se sale del loop.
        while (remaining > 0) {
            for (uint256 i = 0; i < 8; i++) {
                if (remaining == 0) {
                    break;
                }
                uint256 rand = (uint256(keccak256(abi.encodePacked(msg.sender, block.timestamp, block.prevrandao, i, remaining))) % 7) + 1;
                if (rand > remaining) {
                    rand = remaining;
                }
                distribution[i] += rand;
                remaining -= rand;
            }
        }

        return PerformanceStats(
            distribution[0], distribution[1], distribution[2], distribution[3],
            distribution[4], distribution[5], distribution[6], distribution[7]
        );
    }

    function _randomize(uint256 totalPoints, bool keepImage, bool keepStats) internal view returns (HorseBuild memory) {
        bool hasPending = pendingHorse[msg.sender].totalPoints != 0;

        uint256 imgCategory;
        uint256 imgNumber;
        if (keepImage && hasPending) {
            imgCategory = pendingHorse[msg.sender].imgCategory;
            imgNumber = pendingHorse[msg.sender].imgNumber;
        } else {
            (imgCategory, imgNumber) = _randomVisual(totalPoints);
        }

        PerformanceStats memory stats = keepStats && hasPending ? pendingHorse[msg.sender].baseStats : _randomStats(totalPoints);

        return HorseBuild({
            imgCategory: imgCategory,
            imgNumber: imgNumber,
            baseStats: stats,
            totalPoints: totalPoints,
            extraPackagesBought: hasPending ? pendingHorse[msg.sender].extraPackagesBought : 0
        });
    }

    function _randomVisual(uint256 totalPoints) internal view returns (uint256 imgCategory, uint256 imgNumber) {
        require(address(horseStats) != address(0), 'Horse stats not set');
        uint256 entropy = uint256(keccak256(
            abi.encodePacked(msg.sender, block.timestamp, block.prevrandao, totalPoints, nextHorseId)
        ));
        return horseStats.getRandomVisual(entropy);
    }

    // ----------------------------------------------------
    // Admin functions
    // ----------------------------------------------------

    function setHorseStats(address _stats) external onlyAdmin {
        horseStats = IHorseStats(_stats);
    }

    function setSpeedHorses(address _horses) external onlyAdmin {
        speedHorses = ISpeedHorses(_horses);
    }

    function withdrawTLOS(address payable to, uint256 amount) external onlyAdmin {
        require(address(this).balance >= amount, 'Insufficient balance');
        to.transfer(amount);
    }
}
