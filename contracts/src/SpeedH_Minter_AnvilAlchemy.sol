// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import { PerformanceStats } from "./SpeedH_StatsStructs.sol";
import { SpeedH_Stats_Horseshoe } from "./SpeedH_Stats_Horseshoe.sol";

error NotAdmin();
error FusionNotFound();
error InvalidAdmin();
error InvalidErrorMargin();
error InvalidRefundBps();
error InsufficientBalance();
error HayTransferFailed();
error StatsNotSet();
error NftNotSet();
error IncorrectTlosPayment();
error SameParents();
error InvalidParents();
error ParentsEquipped();
error FatherNotApproved();
error MotherNotApproved();
error FusionFinalized();
error FusionAlreadyProcessed();
error NotFusionOwner();
error HayNotSet();
error HayPaymentFailed();
error PreviewMissing();

interface ISpeedH_Stats_Fusion {
    function horseshoeModule() external view returns (SpeedH_Stats_Horseshoe);
    function isHorseshoeEquipped(uint256 horseshoeId) external view returns (bool);
    function getRandomHorseshoeVisual(uint256 entropy) external view returns (uint256, uint256);
    function registerHorseshoeStats(
        uint256 horseshoeId,
        uint256 imgCategory,
        uint256 imgNumber,
        PerformanceStats calldata bonusStats,
        uint256 maxDurability,
        uint256 level,
        bool isPure
    ) external;
}

interface ISpeedH_NFT_Horseshoe_MintBurn is IERC721 {
    function mint(address to) external returns (uint256);
    function burn(uint256 tokenId) external;
}

/**
 * @title SpeedH_Minter_AnvilAlchemy
 * @notice Implements the multi-stage workflow required to fuse two existing horseshoes into a new one.
 *         Users start the process paying in TLOS, randomize as many times as desired paying in HAY and
 *         finally claim the resulting NFT, which burns the two parents and mints a higher level successor.
 *         Cancellation is supported, returning the deposited NFTs and most of the upfront cost.
 */
contract SpeedH_Minter_AnvilAlchemy {
    string public version = "SpeedH_Minter_AnvilAlchemy-v1.0.0";

    // ---------------------------------------------------------------------
    // Configuration
    // ---------------------------------------------------------------------

    address public admin;
    ISpeedH_Stats_Fusion public _contractStats;
    ISpeedH_NFT_Horseshoe_MintBurn public _contractNFTHorseshoe;
    IERC20 public _contractHayToken;

    uint256 public fusionTlosCost = 400 ether;
    uint256 public randomizeHayCost = 40 ether;
    uint256 public parentError = 10; // expressed in percentage points
    uint256 public fusionStatsPool = 20;
    uint256 public cancelRefundBps = 8000; // 80%

    // ---------------------------------------------------------------------
    // Process bookkeeping
    // ---------------------------------------------------------------------

    struct FusionPreview {
        PerformanceStats stats;
        uint256 maxDurability;
        uint256 level;
        bool isPure;
        uint256 imgCategory;
        uint256 imgNumber;
    }

    struct FusionProcess {
        address owner;
        uint256 fatherId;
        uint256 motherId;
        uint256 paidTlos;
        uint256 entropyNonce;
        bool finalized;
        bool hasPreview;
        FusionPreview preview;
    }

    uint256 public nextFusionId = 1;
    mapping(uint256 => FusionProcess) private _fusions;

    // ---------------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------------

    event FusionStarted(uint256 indexed fusionId, address indexed owner, uint256 fatherId, uint256 motherId);
    event FusionRandomized(
        uint256 indexed fusionId,
        uint256 level,
        bool isPure,
        uint256 imgCategory,
        uint256 imgNumber,
        bool keepStats
    );
    event FusionClaimed(uint256 indexed fusionId, uint256 newHorseshoeId);
    event FusionCancelled(uint256 indexed fusionId);

    // ---------------------------------------------------------------------
    // Modifiers
    // ---------------------------------------------------------------------

    modifier onlyAdmin() {
        if (msg.sender != admin) revert NotAdmin();
        _;
    }

    modifier validFusion(uint256 fusionId) {
        if (_fusions[fusionId].owner == address(0)) revert FusionNotFound();
        _;
    }

    constructor() {
        admin = msg.sender;
    }

    // ---------------------------------------------------------------------
    // Admin configuration
    // ---------------------------------------------------------------------

    function setAdmin(address newAdmin) external onlyAdmin {
        if (newAdmin == address(0)) revert InvalidAdmin();
        admin = newAdmin;
    }

    function setContractStats(address contractStats) external onlyAdmin {
        _contractStats = ISpeedH_Stats_Fusion(contractStats);
    }

    function setContractNFTHorseshoe(address contractNFTHorseshoe) external onlyAdmin {
        _contractNFTHorseshoe = ISpeedH_NFT_Horseshoe_MintBurn(contractNFTHorseshoe);
    }

    function setContractHayToken(address contractHayToken) external onlyAdmin {
        _contractHayToken = IERC20(contractHayToken);
    }

    function setFusionTlosCost(uint256 cost) external onlyAdmin {
        fusionTlosCost = cost;
    }

    function setRandomizeHayCost(uint256 cost) external onlyAdmin {
        randomizeHayCost = cost;
    }

    function setParentError(uint256 errorMargin) external onlyAdmin {
        if (errorMargin > 50) revert InvalidErrorMargin();
        parentError = errorMargin;
    }

    function setFusionStatsPool(uint256 pool) external onlyAdmin {
        fusionStatsPool = pool;
    }

    function setCancelRefund(uint256 refundBps) external onlyAdmin {
        if (refundBps > 10_000) revert InvalidRefundBps();
        cancelRefundBps = refundBps;
    }

    function withdrawTLOS(address payable to, uint256 amount) external onlyAdmin {
        if (address(this).balance < amount) revert InsufficientBalance();
        to.transfer(amount);
    }

    function withdrawHAY(address to, uint256 amount) external onlyAdmin {
        if (!_contractHayToken.transfer(to, amount)) revert HayTransferFailed();
    }

    // ---------------------------------------------------------------------
    // User flow
    // ---------------------------------------------------------------------

    function startFusion(uint256 fatherId, uint256 motherId) external payable returns (uint256 fusionId) {
        if (address(_contractStats) == address(0)) revert StatsNotSet();
        if (address(_contractNFTHorseshoe) == address(0)) revert NftNotSet();
        if (msg.value != fusionTlosCost) revert IncorrectTlosPayment();
        if (fatherId == motherId) revert SameParents();

        SpeedH_Stats_Horseshoe horseshoeModule = _contractStats.horseshoeModule();
        SpeedH_Stats_Horseshoe.HorseshoeData memory father = horseshoeModule.getHorseshoe(fatherId);
        SpeedH_Stats_Horseshoe.HorseshoeData memory mother = horseshoeModule.getHorseshoe(motherId);

        if (!(father.maxDurability > 0 && mother.maxDurability > 0)) revert InvalidParents();
        if (
            _contractStats.isHorseshoeEquipped(fatherId) || _contractStats.isHorseshoeEquipped(motherId)
        ) revert ParentsEquipped();
        if (
            _contractNFTHorseshoe.getApproved(fatherId) != address(this)
                && !_contractNFTHorseshoe.isApprovedForAll(msg.sender, address(this))
        ) revert FatherNotApproved();
        if (
            _contractNFTHorseshoe.getApproved(motherId) != address(this)
                && !_contractNFTHorseshoe.isApprovedForAll(msg.sender, address(this))
        ) revert MotherNotApproved();

        _contractNFTHorseshoe.transferFrom(msg.sender, address(this), fatherId);
        _contractNFTHorseshoe.transferFrom(msg.sender, address(this), motherId);

        fusionId = nextFusionId++;
        FusionProcess storage process = _fusions[fusionId];
        process.owner = msg.sender;
        process.fatherId = fatherId;
        process.motherId = motherId;
        process.paidTlos = msg.value;

        emit FusionStarted(fusionId, msg.sender, fatherId, motherId);
    }

    function randomizeFusion(uint256 fusionId, bool keepStats) external validFusion(fusionId) {
        FusionProcess storage process = _fusions[fusionId];
        if (process.finalized) revert FusionFinalized();
        if (process.owner != msg.sender) revert NotFusionOwner();
        if (address(_contractHayToken) == address(0)) revert HayNotSet();

        if (!_contractHayToken.transferFrom(msg.sender, address(this), randomizeHayCost)) {
            revert HayPaymentFailed();
        }

        SpeedH_Stats_Horseshoe horseshoeModule = _contractStats.horseshoeModule();
        SpeedH_Stats_Horseshoe.HorseshoeData memory father = horseshoeModule.getHorseshoe(process.fatherId);
        SpeedH_Stats_Horseshoe.HorseshoeData memory mother = horseshoeModule.getHorseshoe(process.motherId);

        FusionPreview memory preview = _buildPreview(process, father, mother, keepStats);
        process.preview = preview;
        process.hasPreview = true;

        emit FusionRandomized(fusionId, preview.level, preview.isPure, preview.imgCategory, preview.imgNumber, keepStats);
    }

    function claimFusion(uint256 fusionId) external validFusion(fusionId) {
        FusionProcess storage process = _fusions[fusionId];
        if (process.owner != msg.sender) revert NotFusionOwner();
        if (process.finalized) revert FusionAlreadyProcessed();
        if (!process.hasPreview) revert PreviewMissing();

        uint256 fatherId = process.fatherId;
        uint256 motherId = process.motherId;
        FusionPreview memory preview = process.preview;
        address owner = process.owner;

        process.finalized = true;
        process.hasPreview = false;

        _contractNFTHorseshoe.burn(fatherId);
        _contractNFTHorseshoe.burn(motherId);

        uint256 newId = _contractNFTHorseshoe.mint(owner);
        _contractStats.registerHorseshoeStats(
            newId,
            preview.imgCategory,
            preview.imgNumber,
            preview.stats,
            preview.maxDurability,
            preview.level,
            preview.isPure
        );

        delete _fusions[fusionId];

        emit FusionClaimed(fusionId, newId);
    }

    function cancelFusion(uint256 fusionId) external validFusion(fusionId) {
        FusionProcess storage process = _fusions[fusionId];
        if (process.owner != msg.sender) revert NotFusionOwner();
        if (process.finalized) revert FusionAlreadyProcessed();

        process.finalized = true;
        process.hasPreview = false;

        address owner = process.owner;
        uint256 fatherId = process.fatherId;
        uint256 motherId = process.motherId;
        uint256 paidTlos = process.paidTlos;

        _contractNFTHorseshoe.transferFrom(address(this), owner, fatherId);
        _contractNFTHorseshoe.transferFrom(address(this), owner, motherId);

        uint256 refund = (paidTlos * cancelRefundBps) / 10_000;
        if (refund > 0) {
            payable(owner).transfer(refund);
        }

        delete _fusions[fusionId];

        emit FusionCancelled(fusionId);
    }

    function getFusion(uint256 fusionId) external view returns (FusionProcess memory) {
        return _fusions[fusionId];
    }

    // ---------------------------------------------------------------------
    // Internal helpers
    // ---------------------------------------------------------------------

    function _buildPreview(
        FusionProcess storage process,
        SpeedH_Stats_Horseshoe.HorseshoeData memory father,
        SpeedH_Stats_Horseshoe.HorseshoeData memory mother,
        bool keepStats
    ) internal returns (FusionPreview memory) {
        uint256 fatherPct = _percentageFromRandom(_nextEntropy(process, 0x01));
        uint256 motherPct = _percentageFromRandom(_nextEntropy(process, 0x02));
        uint256 ownPct = _percentageFromRandom(_nextEntropy(process, 0x03));
        uint256 visualEntropy = _nextEntropy(process, 0x04);

        PerformanceStats memory combined;
        if (keepStats) {
            combined = _addStats(_scaleStats(father.bonusStats, fatherPct), _scaleStats(mother.bonusStats, motherPct));
            uint256 ownPoints = (fusionStatsPool * ownPct) / 100;
            combined = _addStats(combined, _pointsToStats(ownPoints, _nextEntropy(process, 0x05)));
        } else {
            uint256 parentPoints = _sumStats(_scaleStats(father.bonusStats, fatherPct))
                + _sumStats(_scaleStats(mother.bonusStats, motherPct));
            uint256 totalPoints = parentPoints + ((fusionStatsPool * ownPct) / 100);
            combined = _distributeAcrossTwo(totalPoints, _nextEntropy(process, 0x06));
        }

        uint256 maxDurability = father.maxDurability > mother.maxDurability ? father.maxDurability : mother.maxDurability;

        bool isPure = father.isPure && mother.isPure && father.level == mother.level;
        uint256 level = (father.level > mother.level ? father.level : mother.level) + 1;

        (uint256 imgCategory, uint256 imgNumber) = _contractStats.getRandomHorseshoeVisual(visualEntropy);

        return FusionPreview({
            stats: combined,
            maxDurability: maxDurability,
            level: level,
            isPure: isPure,
            imgCategory: imgCategory,
            imgNumber: imgNumber
        });
    }

    function _percentageFromRandom(uint256 randomValue) internal view returns (uint256) {
        uint256 span = parentError * 2;
        if (span == 0) {
            return 50;
        }
        return 50 - parentError + (randomValue % span);
    }

    function _nextEntropy(FusionProcess storage process, uint256 salt) internal returns (uint256) {
        process.entropyNonce += 1;
        return uint256(
            keccak256(abi.encodePacked(block.timestamp, block.prevrandao, process.owner, process.entropyNonce, salt))
        );
    }

    function _addStats(PerformanceStats memory a, PerformanceStats memory b) internal pure returns (PerformanceStats memory) {
        return
            PerformanceStats({
                power: a.power + b.power,
                acceleration: a.acceleration + b.acceleration,
                stamina: a.stamina + b.stamina,
                minSpeed: a.minSpeed + b.minSpeed,
                maxSpeed: a.maxSpeed + b.maxSpeed,
                luck: a.luck + b.luck,
                curveBonus: a.curveBonus + b.curveBonus,
                straightBonus: a.straightBonus + b.straightBonus
            });
    }

    function _scaleStats(PerformanceStats memory stats, uint256 pct) internal pure returns (PerformanceStats memory) {
        return
            PerformanceStats({
                power: (stats.power * pct) / 100,
                acceleration: (stats.acceleration * pct) / 100,
                stamina: (stats.stamina * pct) / 100,
                minSpeed: (stats.minSpeed * pct) / 100,
                maxSpeed: (stats.maxSpeed * pct) / 100,
                luck: (stats.luck * pct) / 100,
                curveBonus: (stats.curveBonus * pct) / 100,
                straightBonus: (stats.straightBonus * pct) / 100
            });
    }

    function _pointsToStats(uint256 points, uint256 seed) internal pure returns (PerformanceStats memory) {
        uint256[8] memory buckets;
        if (points == 0) {
            return _zeroStats();
        }
        for (uint256 i = 0; i < points; i++) {
            uint256 idx = uint256(keccak256(abi.encode(seed, i))) % 8;
            buckets[idx] += 1;
        }
        return _fromArray(buckets);
    }

    function _distributeAcrossTwo(uint256 totalPoints, uint256 seed) internal pure returns (PerformanceStats memory) {
        if (totalPoints == 0) {
            return _zeroStats();
        }
        uint256 attrA = seed % 8;
        uint256 attrB = (seed / 8) % 8;
        if (attrA == attrB) {
            attrB = (attrB + 1) % 8;
        }
        uint256 shareA = totalPoints == 0 ? 0 : (totalPoints * ((seed / 64) % 101)) / 100;
        if (shareA > totalPoints) {
            shareA = totalPoints;
        }
        uint256 shareB = totalPoints - shareA;

        uint256[8] memory buckets;
        buckets[attrA] = shareA;
        buckets[attrB] = shareB;
        return _fromArray(buckets);
    }

    function _fromArray(uint256[8] memory buckets) internal pure returns (PerformanceStats memory) {
        return
            PerformanceStats({
                power: buckets[0],
                acceleration: buckets[1],
                stamina: buckets[2],
                minSpeed: buckets[3],
                maxSpeed: buckets[4],
                luck: buckets[5],
                curveBonus: buckets[6],
                straightBonus: buckets[7]
            });
    }

    function _sumStats(PerformanceStats memory stats) internal pure returns (uint256) {
        return
            stats.power +
            stats.acceleration +
            stats.stamina +
            stats.minSpeed +
            stats.maxSpeed +
            stats.luck +
            stats.curveBonus +
            stats.straightBonus;
    }

    function _zeroStats() internal pure returns (PerformanceStats memory) {
        return PerformanceStats(0, 0, 0, 0, 0, 0, 0, 0);
    }
}
