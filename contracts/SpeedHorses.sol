// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import '@openzeppelin/contracts/access/Ownable.sol';

contract SpeedHorses is ERC721, Ownable {
    address public admin;
    address public horseMinter;
    address public horseStats;
    string public version = "SpeedHorses-v1.0.0";

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
}


// En vez de interface, definimos un contrato base vacío
contract StatsBase {
    function tokenURI(uint256) external pure virtual returns (string memory) {
        return "";
    }
    // TODO: agregar hasFinishedResting y hasFinishedFeeding.
    // Luego modificar el transfer para verificar que el caballo ha terminado ambas tareas.
}
