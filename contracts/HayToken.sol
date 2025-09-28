// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { ERC20 } from '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import { Ownable } from '@openzeppelin/contracts/access/Ownable.sol';

/**
 * Título: HayToken
 * Brief: Token ERC-20 nativo del ecosistema utilizado para pagos internos como inscripciones, alimentación y recompensas dentro del juego. Está controlado por una cuenta dueña que puede administrar emisiones o políticas futuras a través de las capacidades del contrato base.
 * API: hereda la interfaz estándar de ERC-20 provista por OpenZeppelin (transferencias, aprobaciones, consultas de saldo y supply) y utiliza `Ownable` para exponer funciones administrativas como `transferOwnership`. Su constructor define el nombre y símbolo utilizados en todas las interacciones económicas del proyecto.
 */
contract HayToken is ERC20, Ownable {
    string public version = "HayToken-v1.0.0";

    constructor()
        ERC20('HAY Token', 'HAY')
        Ownable(msg.sender)
    {

    }
}
