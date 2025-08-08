// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { Ownable } from '@openzeppelin/contracts/access/Ownable.sol';
import '@layerzerolabs/lz-evm-oapp-v2/contracts/oft/OFT.sol';

// LayerZero endpoint addresses for each network
// Telos EVM Mainnet:  0x1a44076050125825900e736c501f859c50fE728c
// Ethereum Mainnet:   0x1a44076050125825900e736c501f859c50fE728c
// BNB Smart Chain:    0x1a44076050125825900e736c501f859c50fE728c
// Solana Mainnet:     76y77prsiCMvXMjuoZ5VRrhG5qYBrUMYTE5WgHqgjEn6
// More here: https://docs.layerzero.network/v2/deployments/deployed-contracts

contract HayTokenOFT is Ownable, OFT {
    constructor(
        address _lzEndpoint,
        address _delegate,
        address _initialOwner
    )
        Ownable(_initialOwner) OFT('HAY Token', 'HAY', _lzEndpoint, _delegate)
    {}
}
