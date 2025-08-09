// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { ERC20 } from '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import { Ownable } from '@openzeppelin/contracts/access/Ownable.sol';

contract HayToken is ERC20, Ownable {
    string public version = "HayToken-v1.0.0";

    constructor()
        ERC20('HAY Token', 'HAY')
        Ownable(msg.sender)
    {
        _mint(msg.sender, 1_000_000 ether); // Mint inicial para pruebas
    }
}
