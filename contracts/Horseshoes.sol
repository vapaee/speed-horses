// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import '@openzeppelin/contracts/access/Ownable.sol';

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
    string public version = "Horseshoes-v1.0.0";

    address public admin;
    address public horseMinter;

    modifier onlyAdmin() {
        require(msg.sender == admin, "Not admin");
        _;
    }

    modifier onlyHorseMinter() {
        require(msg.sender == horseMinter, "Not horseMinter");
        _;
    }

    constructor() ERC721("Horseshoes", "SHOE") Ownable(msg.sender) {
        admin = msg.sender;
    }

    function setHorseMinter(address _minter) external onlyAdmin {
        horseMinter = _minter;
    }

    function mint(address to, uint256 tokenId) external onlyHorseMinter {
        _mint(to, tokenId);
    }
}

