// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import '@openzeppelin/contracts/access/Ownable.sol';

/**
 * Título: SpeedH_NFT_Horse
 * Brief: Contrato ERC-721 que representa a los caballos del juego, delega la generación de metadatos y controles de transferencia al módulo de estadísticas y garantiza que sólo el administrador y el minter autorizado puedan acuñar o gestionar los tokens. Administra referencias cruzadas a los contratos que definen atributos y respeta las restricciones de descanso y registro en carreras antes de permitir movimientos.
 * API: expone funciones administrativas para definir los contratos auxiliares (`setContractMinter`, `setContractStats`), un punto de acuñación protegido (`mint`) y la consulta de metadatos (`tokenURI`). Además, sobreescribe `_update` para integrarse en el flujo de juego, verificando en las transferencias que el caballo haya terminado de descansar y que no esté inscrito en competencias, siendo esta validación una etapa previa a cualquier intercambio entre jugadores.
 */
contract SpeedH_NFT_Horse is ERC721, Ownable {
    string public version = "SpeedH_NFT_Horse-v1.0.0";

    // ---------------------------------------------------------------------
    // Contract References
    // ---------------------------------------------------------------------
    address public admin;
    mapping(address => bool) private _contractMinters;
    address public _contractStats;
    uint256 private _totalSupply;

    // Next token id to be minted (auto-incremented)
    uint256 private _nextTokenId;

    modifier onlyAdmin() {
        require(msg.sender == admin, "Not admin");
        _;
    }

    modifier onlyHorseMinter() {
        require(_contractMinters[msg.sender], "Not horseMinter");
        _;
    }

    constructor() ERC721('SpeedHorses', 'HORSE') Ownable(msg.sender) {
        admin = msg.sender;
        // Start from any desired number (e.g., 1). Must be >= 0.
        _nextTokenId = 1;
    }

    event ContractMinterUpdated(address indexed contractMinter, bool allowed);

    function setContractMinter(address contractMinter, bool allowed) external onlyAdmin {
        require(contractMinter != address(0), "Invalid minter");
        _contractMinters[contractMinter] = allowed;
        emit ContractMinterUpdated(contractMinter, allowed);
    }

    function isHorseMinter(address account) external view returns (bool) {
        return _contractMinters[account];
    }

    function setContractStats(address contractStats) external onlyAdmin {
        _contractStats = contractStats;
    }

    function mint(address to) external onlyHorseMinter returns (uint256) {
        uint256 tokenId = _nextTokenId;
        // Increment first to avoid reentrancy issues if receiver calls back
        _nextTokenId = tokenId + 1;

        _safeMint(to, tokenId);
        return tokenId;
    }

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function nextTokenId() external view returns (uint256) {
        return _nextTokenId;
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(ownerOf(tokenId) != address(0), "Token does not exist");
        require(_contractStats != address(0), "horseStats not set");
        return StatsBase(_contractStats).horseTokenURI(tokenId);
    }

    function _update(address to, uint256 tokenId, address auth) internal override returns (address) {
        address from = _ownerOf(tokenId);
        if (from != address(0) && to != address(0)) {
            require(_contractStats != address(0), "horseStats not set");
            StatsBase stats = StatsBase(_contractStats);
            require(stats.hasFinishedResting(tokenId), "Horse still resting");
            require(!stats.isRegisteredForRacing(tokenId), "Horse is registered for racing");
        }
        address previousOwner = super._update(to, tokenId, auth);

        if (from == address(0)) {
            _totalSupply += 1;
        } else if (to == address(0)) {
            _totalSupply -= 1;
        }

        return previousOwner;
    }
}


// En vez de interface, definimos un contrato base vacío
contract StatsBase {
    function horseTokenURI(uint256) external pure virtual returns (string memory) {
        return "";
    }

    function horseshoeTokenURI(uint256) external pure virtual returns (string memory) {
        return "";
    }

    function isRegisteredForRacing(uint256) external pure virtual returns (bool) {
        return true;
    }

    function hasFinishedResting(uint256) external pure virtual returns (bool) {
        return true;
    }

    function isHorseshoeEquipped(uint256) external pure virtual returns (bool) {
        return false;
    }
}
