// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import '@openzeppelin/contracts/access/Ownable.sol';

import './SpeedHorses.sol';

/**
 * Título: Horseshoes
 * Brief: Contrato ERC-721 que representa las herraduras del ecosistema Speed Horses, permitiendo que el juego administre la
 * acuñación de piezas equipables para los caballos. Mantiene un control de acceso sencillo en el que solamente el administrador
 * o el minter autorizado pueden configurar dependencias y emitir nuevos NFTs.
 * API: expone operaciones administrativas para definir el minter (`setHorseMinter`) y un punto de acuñación restringido (`mint`)
 * que delega en el contrato `HorseMinter`. Hereda de `ERC721` y `Ownable` para integrarse sin fricción con el resto de módulos
 * on-chain.
 */
contract Horseshoes is ERC721, Ownable {
    // ---------------------------------------------------------------------
    // Storage
    // ---------------------------------------------------------------------

    string public version = 'Horseshoes-v1.0.0';

    address public admin;
    address public horseMinter;
    address public horseStats;

    // Next token id to be minted (auto-incremented)
    uint256 private _nextTokenId;

    // ---------------------------------------------------------------------
    // Admin functions
    // ---------------------------------------------------------------------

    modifier onlyAdmin() {
        require(msg.sender == admin, 'Not admin');
        _;
    }

    modifier onlyHorseMinter() {
        require(msg.sender == horseMinter, 'Not horseMinter');
        _;
    }

    // ---------------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------------

    constructor() ERC721('Horseshoes', 'SHOE') Ownable(msg.sender) {
        admin = msg.sender;
        // Start from any desired number (e.g., 1). Must be >= 0.
        _nextTokenId = 1;
    }

    // ---------------------------------------------------------------------
    // Admin
    // ---------------------------------------------------------------------

    function setHorseMinter(address _minter) external onlyAdmin {
        horseMinter = _minter;
    }

    function setHorseStats(address _stats) external onlyAdmin {
        horseStats = _stats;
    }

    // ---------------------------------------------------------------------
    // Minting (auto-increment ids)
    // ---------------------------------------------------------------------

    /**
     * Mints a single NFT to `to` using the current `_nextTokenId`, then increments it.
     * Returns the minted token id.
     */
    function mint(address to) external onlyHorseMinter returns (uint256) {
        uint256 tokenId = _nextTokenId;
        // Increment first to avoid reentrancy issues if receiver calls back
        _nextTokenId = tokenId + 1;

        _safeMint(to, tokenId);
        return tokenId;
    }

    // ---------------------------------------------------------------------
    // Views
    // ---------------------------------------------------------------------

    function nextTokenId() external view returns (uint256) {
        return _nextTokenId;
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_ownerOf(tokenId) != address(0), 'Token does not exist');
        require(horseStats != address(0), 'horseStats not set');
        return StatsBase(horseStats).horseshoeTokenURI(tokenId);
    }

    // ---------------------------------------------------------------------
    // Hooks / Overrides
    // ---------------------------------------------------------------------

    /**
     * Prevent transfers while a horseshoe is equipped. Mirrors your original logic.
     * OpenZeppelin v5 uses _update; keep the check before calling super.
     */
    function _update(address to, uint256 tokenId, address auth) internal override returns (address) {
        address from = _ownerOf(tokenId);
        if (from != address(0) && to != address(0)) {
            require(horseStats != address(0), 'horseStats not set');
            require(!StatsBase(horseStats).isHorseshoeEquipped(tokenId), 'Horseshoe equipped');
        }
        return super._update(to, tokenId, auth);
    }
}
