// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Ownable } from '@openzeppelin/contracts/access/Ownable.sol';
import '@layerzerolabs/lz-evm-oapp-v2/contracts/oft/OFT.sol';

// LayerZero endpoint addresses for each network
// Telos EVM Mainnet:  0x1a44076050125825900e736c501f859c50fE728c
// Ethereum Mainnet:   0x1a44076050125825900e736c501f859c50fE728c
// BNB Smart Chain:    0x1a44076050125825900e736c501f859c50fE728c
// Solana Mainnet:     76y77prsiCMvXMjuoZ5VRrhG5qYBrUMYTE5WgHqgjEn6
// More here: https://docs.layerzero.network/v2/deployments/deployed-contracts

/**
 * Título: SpeedH_HayTokenOFT
 * Brief: Versión omnichain del token HAY basada en LayerZero que habilita transferencias entre cadenas mientras conserva control de propiedad. Sirve como puente entre ecosistemas, permitiendo que el activo utilitario del juego circule más allá de la red principal manteniendo registro del endpoint y el delegado del protocolo.
 * API: se apoya en las funciones de la clase `OFT` (envío y recepción entre cadenas, gestión de cuotas, etc.) y en `Ownable` para tareas administrativas como configurar el delegado. Su constructor establece los parámetros de despliegue (`_lzEndpoint`, `_delegate`, `_initialOwner`), integrando el token a los flujos de mensajería de LayerZero usados en procesos de interoperabilidad.
 */
contract SpeedH_HayTokenOFT is Ownable, OFT {
    string public version = "SpeedH_HayTokenOFT-v1.0.0";
    constructor(
        address _lzEndpoint,
        address _delegate,
        address _initialOwner
    )
        Ownable(_initialOwner) OFT('HAY Token', 'HAY', _lzEndpoint, _delegate)
    {}
}
