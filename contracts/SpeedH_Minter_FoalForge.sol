// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { PerformanceStats } from "./SpeedH_StatsStructs.sol";

interface ISpeedH_Stats_Horse {
    function createHorseStats(
        uint256 horseId,
        uint256 imgCategory,
        uint256 imgNumber,
        PerformanceStats calldata baseStats
    ) external;
    function getRandomVisual(uint256 entropy) external view returns (uint256 imgCategory, uint256 imgNumber);
    function getRandomHorseshoeVisual(uint256 entropy) external view returns (uint256 imgCategory, uint256 imgNumber);
    function registerStarterHorseshoeStats(
        uint256 horseId,
        uint256 horseshoeId,
        uint256 imgCategory,
        uint256 imgNumber,
        PerformanceStats calldata bonusStats,
        uint256 maxDurability,
        uint256 level,
        bool isPure
    ) external;
}

interface ISpeedH_NFT_Horse {
    function mint(address to, uint256 horseId) external;
}

interface ISpeedH_NFT_Horseshoe {
    function mint(address to) external returns (uint256);
    function nextTokenId() external view returns (uint256);
}

/**
 * Título: SpeedH_Minter_FoalForge
 * Brief: Coordinador del proceso de creación de caballos que cobra tarifas en TLOS y genera las combinaciones iniciales de categorías de imagen y estadísticas para cada jugador antes de acuñar el NFT y registrar sus atributos definitivos. Gestiona el flujo de construcción incremental, contabiliza los paquetes de puntos extra adquiridos y comunica los resultados al contrato de estadísticas y al ERC-721 del juego.
 * API: ofrece funciones públicas que modelan el proceso de minteo en etapas (`startHorseMint`, `randomizeHorse`, `buyExtraPoints`, `claimHorse`), cada una avanzando el estado del caballo pendiente y validando pagos y límites; incluye utilidades pseudoaleatorias para categorías de imagen y estadísticas (`_randomHorseStats`, `_randomVisual`, `_randomizeAll`) utilizadas durante dicho proceso. El administrador conecta dependencias y gestiona fondos mediante `setHorseStats`, `setSpeedHorses` y `withdrawTLOS`, completando así el circuito operativo del minter.
 */
contract SpeedH_Minter_FoalForge {
    string public version = "SpeedH_Minter_FoalForge-v1.1.0";

    // ---------------------------------------------------------------------
    // Contract References
    // ---------------------------------------------------------------------
    address public admin;
    ISpeedH_Stats_Horse public horseStats;
    ISpeedH_NFT_Horse public speedHorses;
    ISpeedH_NFT_Horseshoe public horseshoes;

    // ---------------------------------------------------------------------
    // Constants
    // ---------------------------------------------------------------------
    uint256 public constant BASE_CREATION_COST = 600 ether; // en TLOS
    uint256 public constant RANDOMIZE_COST = 100 ether;     // en TLOS
    uint256 public constant EXTRA_POINTS_COST = 200 ether;  // en TLOS
    uint256 public constant MAX_EXTRA_PACKAGES = 4;
    uint256 public constant BASE_INITIAL_POINTS = 60;
    uint256 public constant EXTRA_POINTS_PER_PACKAGE = 10;
    uint256 public constant HORSESHOES_PER_HORSE = 4;
    uint256 public constant STARTER_HORSESHOE_DURABILITY = 100;
    uint256 public constant STARTER_HORSESHOE_LEVEL = 3;
    uint256 public constant STARTER_HORSESHOE_POINTS = 8;

    uint256 public nextHorseId;

    struct PendingHorseshoe {
        uint256 imgCategory;
        uint256 imgNumber;
        PerformanceStats bonusStats;
    }

    struct HorseBuild {
        uint256 imgCategory;
        uint256 imgNumber;
        PerformanceStats baseStats;
        uint256 totalPoints;
        uint8 extraPackagesBought;
        PendingHorseshoe[HORSESHOES_PER_HORSE] horseshoes;
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

        HorseBuild memory newHorse = _randomizeAll(BASE_INITIAL_POINTS, false, false, false);

        pendingHorse[msg.sender] = newHorse;
    }

    function randomizeHorse(bool keepImage, bool keepStats, bool keepShoes) external payable {
        require(!(keepImage && keepStats && keepShoes), 'Cannot lock everything');

        HorseBuild storage build = pendingHorse[msg.sender];
        require(build.totalPoints != 0, 'No horse to randomize');
        require(msg.value == RANDOMIZE_COST, 'Incorrect TLOS amount');

        pendingHorse[msg.sender] = _randomizeAll(build.totalPoints, keepImage, keepStats, keepShoes);
    }

    function buyExtraPoints() external payable {
        HorseBuild storage build = pendingHorse[msg.sender];
        require(build.totalPoints != 0, 'No horse to upgrade');
        require(build.extraPackagesBought < MAX_EXTRA_PACKAGES, 'Max extra points reached');
        require(msg.value == EXTRA_POINTS_COST, 'Incorrect TLOS amount');

        build.extraPackagesBought += 1;
        build.totalPoints = BASE_INITIAL_POINTS + (build.extraPackagesBought * EXTRA_POINTS_PER_PACKAGE);
        build.baseStats = _randomHorseStats(build.totalPoints);
    }

    function claimHorse() external {
        HorseBuild storage build = pendingHorse[msg.sender];
        require(build.totalPoints != 0, 'No horse to claim');

        require(address(horseshoes) != address(0), 'SpeedH_NFT_Horseshoe not set');

        uint256 horseId = nextHorseId++;
        speedHorses.mint(msg.sender, horseId);
        horseStats.createHorseStats(horseId, build.imgCategory, build.imgNumber, build.baseStats);

        for (uint256 i = 0; i < HORSESHOES_PER_HORSE; i++) {
            PendingHorseshoe memory shoe = build.horseshoes[i];
            uint256 horseshoeId = horseshoes.mint(msg.sender);
            horseStats.registerStarterHorseshoeStats(
                horseId,
                horseshoeId,
                shoe.imgCategory,
                shoe.imgNumber,
                shoe.bonusStats,
                STARTER_HORSESHOE_DURABILITY,
                STARTER_HORSESHOE_LEVEL,
                true
            );
        }

        delete pendingHorse[msg.sender];
    }

    // ----------------------------------------------------
    // Random Helpers (pseudo-random, no para mainnet)
    // ----------------------------------------------------

    function _randomizeAll(uint256 totalPoints, bool keepImage, bool keepStats, bool keepShoes) internal view returns (HorseBuild memory) {
        bool hasPending = pendingHorse[msg.sender].totalPoints != 0;

        // Randomize visual
        uint256 imgCategory;
        uint256 imgNumber;
        if (keepImage && hasPending) {
            imgCategory = pendingHorse[msg.sender].imgCategory;
            imgNumber = pendingHorse[msg.sender].imgNumber;
        } else {
            (imgCategory, imgNumber) = _randomVisual(totalPoints);
        }

        // Randomize Horse Stats
        PerformanceStats memory stats = keepStats && hasPending ? pendingHorse[msg.sender].baseStats : _randomHorseStats(totalPoints);

        // Randomize Horseshoes
        PendingHorseshoe[HORSESHOES_PER_HORSE] memory shoes;
        if (keepShoes && hasPending) {
            for (uint256 i = 0; i < HORSESHOES_PER_HORSE; i++) {
                shoes[i] = pendingHorse[msg.sender].horseshoes[i];
            }
        } else {
            shoes = _randomHorseshoes();
        }

        HorseBuild memory build;
        build.imgCategory = imgCategory;
        build.imgNumber = imgNumber;
        build.baseStats = stats;
        build.totalPoints = totalPoints;
        build.extraPackagesBought = hasPending ? pendingHorse[msg.sender].extraPackagesBought : 0;
        for (uint256 i = 0; i < HORSESHOES_PER_HORSE; i++) {
            build.horseshoes[i] = shoes[i];
        }

        return build;
    }

    function _randomVisual(uint256 totalPoints) internal view returns (uint256 imgCategory, uint256 imgNumber) {
        require(address(horseStats) != address(0), 'Horse stats not set');
        require(address(horseshoes) != address(0), 'Horseshoe NFT not set');
        uint256 entropy = uint256(keccak256(
            abi.encodePacked(msg.sender, block.timestamp, block.prevrandao, totalPoints, nextHorseId)
        ));
        return horseStats.getRandomVisual(entropy);
    }

    function _randomHorseshoes() internal view returns (PendingHorseshoe[HORSESHOES_PER_HORSE] memory result) {
        require(address(horseStats) != address(0), 'Horse stats not set');
        uint256 baseId = horseshoes.nextTokenId();
        for (uint256 i = 0; i < HORSESHOES_PER_HORSE; i++) {
            uint256 entropy = uint256(
                keccak256(abi.encodePacked(msg.sender, block.timestamp, block.prevrandao, nextHorseId, baseId, i))
            );
            (uint256 imgCategory, uint256 imgNumber) = horseStats.getRandomHorseshoeVisual(entropy);
            PerformanceStats memory stats = _randomHorseshoeStats(entropy);
            result[i] = PendingHorseshoe({ imgCategory: imgCategory, imgNumber: imgNumber, bonusStats: stats });
        }
    }

    function _randomHorseStats(uint256 totalPoints) public view returns (PerformanceStats memory) {
        uint256[8] memory distribution;
        uint256 remaining = totalPoints;

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

    function _randomHorseshoeStats(uint256 entropy) internal pure returns (PerformanceStats memory) {
        uint256 firstIndex = entropy % 8;
        uint256 secondIndex = uint256(keccak256(abi.encodePacked(entropy, "shoe-second"))) % 8;
        if (secondIndex == firstIndex) {
            secondIndex = (secondIndex + 1) % 8;
        }

        uint256 firstPoints = (uint256(keccak256(abi.encodePacked(entropy, "shoe-points"))) % (STARTER_HORSESHOE_POINTS - 1)) + 1;
        uint256 secondPoints = STARTER_HORSESHOE_POINTS - firstPoints;

        uint256[8] memory distribution;
        distribution[firstIndex] = firstPoints;
        distribution[secondIndex] = secondPoints;

        return PerformanceStats(
            distribution[0],
            distribution[1],
            distribution[2],
            distribution[3],
            distribution[4],
            distribution[5],
            distribution[6],
            distribution[7]
        );
    }

    // ----------------------------------------------------
    // Admin functions
    // ----------------------------------------------------

    function setHorseStats(address _stats) external onlyAdmin {
        horseStats = ISpeedH_Stats_Horse(_stats);
    }

    function setSpeedHorses(address _horses) external onlyAdmin {
        speedHorses = ISpeedH_NFT_Horse(_horses);
    }

    function setHorseshoes(address _horseshoes) external onlyAdmin {
        horseshoes = ISpeedH_NFT_Horseshoe(_horseshoes);
    }

    function withdrawTLOS(address payable to, uint256 amount) external onlyAdmin {
        require(address(this).balance >= amount, 'Insufficient balance');
        to.transfer(amount);
    }
}
