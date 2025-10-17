// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import { PerformanceStats } from "./SpeedH_StatsStructs.sol";
import { SpeedH_Stats_Horseshoe } from "./SpeedH_Stats_Horseshoe.sol";

error NotAdmin();
error RepairNotFound();
error InvalidAdmin();
error InvalidPercent();
error InvalidRefundBps();
error InsufficientBalance();
error HayTransferFailed();
error StatsNotSet();
error NftNotSet();
error IncorrectTlosPayment();
error UnknownHorseshoe();
error HorseshoeEquipped();
error ApprovalMissing();
error RepairFinalized();
error RepairAlreadyProcessed();
error NotRepairOwner();
error HayNotSet();
error HayPaymentFailed();
error PreviewMissing();

interface ISpeedH_Stats_Repair {
    function horseshoeModule() external view returns (SpeedH_Stats_Horseshoe);
    function isHorseshoeEquipped(uint256 horseshoeId) external view returns (bool);
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

interface ISpeedH_NFT_Horseshoe_Escrow is IERC721 {
    function mint(address to) external returns (uint256);
    function burn(uint256 tokenId) external;
}

/**
 * @title SpeedH_Minter_IronRedemption
 * @notice Handles the staged repair flow for a single horseshoe. Users lock the NFT and pay TLOS, randomize
 *         the outcome with HAY as many times as desired and finally claim a freshly minted replacement that
 *         mirrors (with possible degradation) the original statistics. Cancelling returns the NFT and a partial
 *         refund of the initial fee.
 */
contract SpeedH_Minter_IronRedemption {
    string public version = "SpeedH_Minter_IronRedemption-v1.0.0";

    // ---------------------------------------------------------------------
    // Configuration
    // ---------------------------------------------------------------------

    address public admin;
    ISpeedH_Stats_Repair public _contractStats;
    ISpeedH_NFT_Horseshoe_Escrow public _contractNFTHorseshoe;
    IERC20 public _contractHayToken;

    uint256 public repairTlosCost = 200 ether;
    uint256 public randomizeHayCost = 20 ether;
    uint256 public maxPercentError = 25; // maximum loss percentage
    uint256 public cancelRefundBps = 8500; // 85%

    struct RepairPreview {
        PerformanceStats stats;
        uint256 maxDurability;
        uint256 level;
        bool isPure;
        uint256 imgCategory;
        uint256 imgNumber;
    }

    struct RepairProcess {
        address owner;
        uint256 tokenId;
        uint256 paidTlos;
        uint256 entropyNonce;
        bool finalized;
        bool hasPreview;
        RepairPreview baseline;
        RepairPreview preview;
    }

    uint256 public nextRepairId = 1;
    mapping(uint256 => RepairProcess) private _repairs;

    // ---------------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------------

    event RepairStarted(uint256 indexed repairId, address indexed owner, uint256 tokenId);
    event RepairRandomized(uint256 indexed repairId, uint256 level, bool isPure, uint256 errorPct);
    event RepairClaimed(uint256 indexed repairId, uint256 newHorseshoeId);
    event RepairCancelled(uint256 indexed repairId);

    modifier onlyAdmin() {
        if (msg.sender != admin) revert NotAdmin();
        _;
    }

    modifier validRepair(uint256 repairId) {
        if (_repairs[repairId].owner == address(0)) revert RepairNotFound();
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
        _contractStats = ISpeedH_Stats_Repair(contractStats);
    }

    function setContractNFTHorseshoe(address contractNFTHorseshoe) external onlyAdmin {
        _contractNFTHorseshoe = ISpeedH_NFT_Horseshoe_Escrow(contractNFTHorseshoe);
    }

    function setContractHayToken(address contractHayToken) external onlyAdmin {
        _contractHayToken = IERC20(contractHayToken);
    }

    function setRepairTlosCost(uint256 cost) external onlyAdmin {
        repairTlosCost = cost;
    }

    function setRandomizeHayCost(uint256 cost) external onlyAdmin {
        randomizeHayCost = cost;
    }

    function setMaxPercentError(uint256 value) external onlyAdmin {
        if (value > 100) revert InvalidPercent();
        maxPercentError = value;
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

    function startRepair(uint256 tokenId) external payable returns (uint256 repairId) {
        if (address(_contractStats) == address(0)) revert StatsNotSet();
        if (address(_contractNFTHorseshoe) == address(0)) revert NftNotSet();
        if (msg.value != repairTlosCost) revert IncorrectTlosPayment();

        SpeedH_Stats_Horseshoe horseshoeModule = _contractStats.horseshoeModule();
        SpeedH_Stats_Horseshoe.HorseshoeData memory data = horseshoeModule.getHorseshoe(tokenId);
        if (data.maxDurability == 0) revert UnknownHorseshoe();
        if (_contractStats.isHorseshoeEquipped(tokenId)) revert HorseshoeEquipped();
        if (
            _contractNFTHorseshoe.getApproved(tokenId) != address(this)
                && !_contractNFTHorseshoe.isApprovedForAll(msg.sender, address(this))
        ) revert ApprovalMissing();

        _contractNFTHorseshoe.transferFrom(msg.sender, address(this), tokenId);

        repairId = nextRepairId++;
        RepairProcess storage process = _repairs[repairId];
        process.owner = msg.sender;
        process.tokenId = tokenId;
        process.paidTlos = msg.value;
        RepairPreview memory snapshot = RepairPreview({
            stats: data.bonusStats,
            maxDurability: data.maxDurability,
            level: data.level,
            isPure: data.isPure,
            imgCategory: data.imgCategory,
            imgNumber: data.imgNumber
        });
        process.baseline = snapshot;
        process.preview = snapshot;

        emit RepairStarted(repairId, msg.sender, tokenId);
    }

    function randomizeRepair(uint256 repairId) external validRepair(repairId) {
        RepairProcess storage process = _repairs[repairId];
        if (process.finalized) revert RepairFinalized();
        if (process.owner != msg.sender) revert NotRepairOwner();
        if (address(_contractHayToken) == address(0)) revert HayNotSet();

        if (!_contractHayToken.transferFrom(msg.sender, address(this), randomizeHayCost)) {
            revert HayPaymentFailed();
        }

        uint256 errorPct = _nextEntropy(process) % (maxPercentError + 1);
        RepairPreview memory base = process.baseline;

        PerformanceStats memory degraded = _scaleStats(base.stats, 100 - errorPct);
        bool isPure = base.isPure && errorPct == 0;

        RepairPreview memory preview = RepairPreview({
            stats: degraded,
            maxDurability: base.maxDurability,
            level: base.level,
            isPure: isPure,
            imgCategory: base.imgCategory,
            imgNumber: base.imgNumber
        });

        process.preview = preview;
        process.hasPreview = true;

        emit RepairRandomized(repairId, preview.level, preview.isPure, errorPct);
    }

    function claimRepair(uint256 repairId) external validRepair(repairId) {
        RepairProcess storage process = _repairs[repairId];
        if (process.owner != msg.sender) revert NotRepairOwner();
        if (process.finalized) revert RepairAlreadyProcessed();
        if (!process.hasPreview) revert PreviewMissing();

        uint256 tokenId = process.tokenId;
        RepairPreview memory preview = process.preview;
        address owner = process.owner;

        process.finalized = true;
        process.hasPreview = false;

        _contractNFTHorseshoe.burn(tokenId);

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

        delete _repairs[repairId];

        emit RepairClaimed(repairId, newId);
    }

    function cancelRepair(uint256 repairId) external validRepair(repairId) {
        RepairProcess storage process = _repairs[repairId];
        if (process.owner != msg.sender) revert NotRepairOwner();
        if (process.finalized) revert RepairAlreadyProcessed();

        process.finalized = true;
        process.hasPreview = false;

        address owner = process.owner;
        uint256 tokenId = process.tokenId;
        uint256 paidTlos = process.paidTlos;

        _contractNFTHorseshoe.transferFrom(address(this), owner, tokenId);

        uint256 refund = (paidTlos * cancelRefundBps) / 10_000;
        if (refund > 0) {
            payable(owner).transfer(refund);
        }

        delete _repairs[repairId];

        emit RepairCancelled(repairId);
    }

    function getRepair(uint256 repairId) external view returns (RepairProcess memory) {
        return _repairs[repairId];
    }

    // ---------------------------------------------------------------------
    // Internal helpers
    // ---------------------------------------------------------------------

    function _nextEntropy(RepairProcess storage process) internal returns (uint256) {
        process.entropyNonce += 1;
        return uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, process.owner, process.entropyNonce)));
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
}
