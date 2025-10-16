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
    function mint(address to) external returns (uint256);
    function nextTokenId() external view returns (uint256);
}

interface ISpeedH_NFT_Horseshoe {
    function mint(address to) external returns (uint256);
    function nextTokenId() external view returns (uint256);
}

/**
 * Title: SpeedH_Minter_FoalForge
 * Brief: Orchestrates horse creation, charges TLOS fees, generates initial visuals and stats,
 *        and coordinates with stats and NFTs. Provides staged minting API and pseudo-random helpers.
 */
contract SpeedH_Minter_FoalForge {
    string public version = 'SpeedH_Minter_FoalForge-v1.1.0';

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
    uint256 public constant BASE_CREATION_COST = 600 ether; // in TLOS
    uint256 public constant RANDOMIZE_COST = 100 ether;     // in TLOS
    uint256 public constant EXTRA_POINTS_COST = 200 ether;  // in TLOS
    uint256 public constant MAX_EXTRA_PACKAGES = 4;
    uint256 public constant BASE_INITIAL_POINTS = 60;
    uint256 public constant EXTRA_POINTS_PER_PACKAGE = 10;
    uint256 public constant HORSESHOES_PER_HORSE = 4;
    uint256 public constant STARTER_HORSESHOE_DURABILITY = 100;
    uint256 public constant STARTER_HORSESHOE_LEVEL = 2;
    uint256 public constant STARTER_HORSESHOE_POINTS = 4;

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
    }

    // ---------------------------------------------------------------------
    // Public API
    // ---------------------------------------------------------------------

    function startHorseMint() external payable {
        require(address(horseStats) != address(0), 'Horse stats not set');
        require(address(speedHorses) != address(0), 'SpeedH_NFT_Horse not set');
        require(address(horseshoes) != address(0), 'SpeedH_NFT_Horseshoe not set');
        require(pendingHorse[msg.sender].totalPoints == 0, 'Already minting a horse');
        require(msg.value == BASE_CREATION_COST, 'Incorrect TLOS amount');

        // Generate new randomized build (image, stats, shoes)
        HorseBuild memory newHorse = _randomizeAll(BASE_INITIAL_POINTS, false, false, false);

        // Store field-by-field (no direct assignment)
        _applyBuildToStorage(msg.sender, newHorse);
    }

    function randomizeHorse(bool keepImage, bool keepStats, bool keepShoes) external payable {
        require(address(horseStats) != address(0), 'Horse stats not set');
        require(address(speedHorses) != address(0), 'SpeedH_NFT_Horse not set');
        require(address(horseshoes) != address(0), 'SpeedH_NFT_Horseshoe not set');
        require(!(keepImage && keepStats && keepShoes), 'Cannot lock everything');

        HorseBuild storage build = pendingHorse[msg.sender];
        require(build.totalPoints != 0, 'No horse to randomize');
        require(msg.value == RANDOMIZE_COST, 'Incorrect TLOS amount');

        // Generate new randomized build based on keep-flags
        HorseBuild memory newBuild = _randomizeAll(build.totalPoints, keepImage, keepStats, keepShoes);

        // Store field-by-field via the same helper
        _applyBuildToStorage(msg.sender, newBuild);
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

        require(address(horseStats) != address(0), 'Horse stats not set');
        require(address(speedHorses) != address(0), 'SpeedH_NFT_Horse not set');
        require(address(horseshoes) != address(0), 'SpeedH_NFT_Horseshoe not set');

        uint256 horseId = speedHorses.mint(msg.sender);
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
    // Internal helpers
    // ----------------------------------------------------

    /**
     * @dev Copy-by-fields writer to storage to avoid direct struct assignment.
     *      Keeps behavior consistent between start and randomize flows.
     */
    function _applyBuildToStorage(address user, HorseBuild memory newBuild) private {
        HorseBuild storage dst = pendingHorse[user];

        // copy scalars
        dst.imgCategory = newBuild.imgCategory;
        dst.imgNumber = newBuild.imgNumber;
        dst.baseStats = newBuild.baseStats;
        dst.totalPoints = newBuild.totalPoints;
        dst.extraPackagesBought = newBuild.extraPackagesBought;

        // copy fixed-size array items
        for (uint256 i = 0; i < HORSESHOES_PER_HORSE; i++) {
            dst.horseshoes[i] = newBuild.horseshoes[i];
        }
    }

    // ----------------------------------------------------
    // Random Helpers (pseudo-random, not for mainnet)
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
        PerformanceStats memory stats = (keepStats && hasPending)
            ? pendingHorse[msg.sender].baseStats
            : _randomHorseStats(totalPoints);

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
        uint256 entropy = uint256(
            keccak256(
                abi.encodePacked(
                    msg.sender,
                    block.timestamp,
                    block.prevrandao,
                    totalPoints,
                    speedHorses.nextTokenId()
                )
            )
        );
        return horseStats.getRandomVisual(entropy);
    }

    function _randomHorseshoes() internal view returns (PendingHorseshoe[HORSESHOES_PER_HORSE] memory result) {
        require(address(horseStats) != address(0), 'Horse stats not set');
        uint256 baseId = horseshoes.nextTokenId();
        uint256 horseBaseId = speedHorses.nextTokenId();
        for (uint256 i = 0; i < HORSESHOES_PER_HORSE; i++) {
            uint256 entropy = uint256(
                keccak256(
                    abi.encodePacked(
                        msg.sender,
                        block.timestamp,
                        block.prevrandao,
                        horseBaseId,
                        baseId,
                        i
                    )
                )
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
        uint256 secondIndex = uint256(keccak256(abi.encodePacked(entropy, 'shoe-second'))) % 8;
        if (secondIndex == firstIndex) {
            secondIndex = (secondIndex + 1) % 8;
        }

        uint256 firstPoints = (uint256(keccak256(abi.encodePacked(entropy, 'shoe-points'))) % (STARTER_HORSESHOE_POINTS - 1)) + 1;
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
        require(_stats != address(0), 'Invalid stats address');
        horseStats = ISpeedH_Stats_Horse(_stats);
    }

    function setSpeedHorses(address _horses) external onlyAdmin {
        require(_horses != address(0), 'Invalid horses NFT');
        speedHorses = ISpeedH_NFT_Horse(_horses);
    }

    function setHorseshoes(address _horseshoes) external onlyAdmin {
        require(_horseshoes != address(0), 'Invalid horseshoe NFT');
        horseshoes = ISpeedH_NFT_Horseshoe(_horseshoes);
    }

    function withdrawTLOS(address payable to, uint256 amount) external onlyAdmin {
        require(address(this).balance >= amount, 'Insufficient balance');
        to.transfer(amount);
    }
}
