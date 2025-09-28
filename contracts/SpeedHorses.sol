// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import '@openzeppelin/contracts/access/Ownable.sol';

/**
 * Título: SpeedHorses
 * Brief: Contrato ERC-721 que representa a los caballos del juego, delega la generación de metadatos y controles de transferencia al módulo de estadísticas y garantiza que sólo el administrador y el minter autorizado puedan acuñar o gestionar los tokens. Administra referencias cruzadas a los contratos que definen atributos y respeta las restricciones de descanso y registro en carreras antes de permitir movimientos.
 * API: expone funciones administrativas para definir los contratos auxiliares (`setHorseMinter`, `setHorseStats`), un punto de acuñación protegido (`mint`) y la consulta de metadatos (`tokenURI`). Además, sobreescribe `_update` para integrarse en el flujo de juego, verificando en las transferencias que el caballo haya terminado de descansar y que no esté inscrito en competencias, siendo esta validación una etapa previa a cualquier intercambio entre jugadores.
 */
contract SpeedHorses is ERC721, Ownable {
    string public version = "SpeedHorses-v1.0.0";

    // ---------------------------------------------------------------------
    // Contract References
    // ---------------------------------------------------------------------
    address public admin;
    address public horseMinter;
    address public horseStats;

    modifier onlyAdmin() {
        require(msg.sender == admin, "Not admin");
        _;
    }

    modifier onlyHorseMinter() {
        require(msg.sender == horseMinter, "Not horseMinter");
        _;
    }

    constructor() ERC721('SpeedHorses', 'HORSE') Ownable(msg.sender) {
        admin = msg.sender;
    }

    function setHorseMinter(address _minter) external onlyAdmin {
        horseMinter = _minter;
    }

    function setHorseStats(address _stats) external onlyAdmin {
        horseStats = _stats;
    }

    function mint(address to, uint256 id) external onlyHorseMinter {
        _mint(to, id);
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(ownerOf(tokenId) != address(0), "Token does not exist");
        require(horseStats != address(0), "horseStats not set");
        return StatsBase(horseStats).tokenURI(tokenId);
    }

    function _update(address to, uint256 tokenId, address auth) internal override returns (address) {
        address from = _ownerOf(tokenId);
        if (from != address(0) && to != address(0)) {
            require(horseStats != address(0), "horseStats not set");
            StatsBase stats = StatsBase(horseStats);
            require(stats.hasFinishedResting(tokenId), "Horse still resting");
            require(!stats.isRegisteredForRacing(tokenId), "Horse is registered for racing");
        }
        return super._update(to, tokenId, auth);
    }
}


// En vez de interface, definimos un contrato base vacío
contract StatsBase {
    function tokenURI(uint256) external pure virtual returns (string memory) {
        return "";
    }

    function isRegisteredForRacing(uint256) external pure virtual returns (bool) {
        return true;
    }

    function hasFinishedResting(uint256) external pure virtual returns (bool) {
        return true;
    }
}
