// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { PerformanceStats, CooldownStats } from "./StatsStructs.sol";

interface IHorseStats {
    function createHorse(uint256 horseId, uint256 color, PerformanceStats calldata baseStats) external;
}

interface ISpeedHorses {
    function mint(address to, uint256 horseId) external;
}

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
        uint256 color;
        PerformanceStats baseStats;
        uint256 totalPoints;
        uint8 extraPackagesBought;
        bool exists;
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
        require(!pendingHorse[msg.sender].exists, 'Already minting a horse');
        require(msg.value == BASE_CREATION_COST, 'Incorrect TLOS amount');

        HorseBuild memory newHorse = _randomize(BASE_INITIAL_POINTS, false, false);
        newHorse.exists = true;

        pendingHorse[msg.sender] = newHorse;
    }

    function randomizeHorse(bool keepColor, bool keepStats) external payable {
        require(!(keepColor && keepStats), 'Cannot fix both color and stats');

        HorseBuild storage build = pendingHorse[msg.sender];
        require(build.exists, 'No horse to randomize');
        require(msg.value == RANDOMIZE_COST, 'Incorrect TLOS amount');

        pendingHorse[msg.sender] = _randomize(build.totalPoints, keepColor, keepStats);
        pendingHorse[msg.sender].exists = true;
        pendingHorse[msg.sender].extraPackagesBought = build.extraPackagesBought;
    }

    function buyExtraPoints() external payable {
        HorseBuild storage build = pendingHorse[msg.sender];
        require(build.exists, 'No horse to upgrade');
        require(build.extraPackagesBought < MAX_EXTRA_PACKAGES, 'Max extra points reached');
        require(msg.value == EXTRA_POINTS_COST, 'Incorrect TLOS amount');

        build.extraPackagesBought += 1;
        build.totalPoints = BASE_INITIAL_POINTS + (build.extraPackagesBought * EXTRA_POINTS_PER_PACKAGE);
        build.baseStats = _randomStats(build.totalPoints);
    }

    function claimHorse() external {
        HorseBuild storage build = pendingHorse[msg.sender];
        require(build.exists, 'No horse to claim');

        uint256 horseId = nextHorseId++;
        speedHorses.mint(msg.sender, horseId);
        horseStats.createHorse(horseId, build.color, build.baseStats);

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

    function _randomColor() internal view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(msg.sender, block.timestamp, block.prevrandao))) % 10;
    }

    function _randomize(uint256 totalPoints, bool keepColor, bool keepStats) internal view returns (HorseBuild memory) {
        uint256 color = keepColor && pendingHorse[msg.sender].exists ? pendingHorse[msg.sender].color : _randomColor();
        PerformanceStats memory stats = keepStats && pendingHorse[msg.sender].exists ? pendingHorse[msg.sender].baseStats : _randomStats(totalPoints);

        return HorseBuild({
            color: color,
            baseStats: stats,
            totalPoints: totalPoints,
            extraPackagesBought: pendingHorse[msg.sender].exists ? pendingHorse[msg.sender].extraPackagesBought : 0,
            exists: true
        });
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
