import { HardhatUserConfig } from 'hardhat/config';
import '@nomicfoundation/hardhat-ethers';
import * as fs from 'fs';
import * as path from 'path';
import * as dotenv from 'dotenv';

dotenv.config();

const readAccounts = (): string[] => {
    const pkFile = process.env.PRIVATE_KEY_FILE;
    if (!pkFile) {
        return [];
    }
    try {
        const resolved = path.resolve(pkFile);
        const raw = fs.readFileSync(resolved, 'utf8').trim();
        if (!raw) {
            return [];
        }
        return [raw.startsWith('0x') ? raw : `0x${raw}`];
    } catch (error) {
        return [];
    }
};

const accounts = readAccounts();

const config: HardhatUserConfig = {
    solidity: {
        version: '0.8.24',
        settings: {
            optimizer: {
                enabled: true,
                runs: 200
            }
        }
    },
    networks: {
        telosTestnet: {
            url: process.env.TELOS_EVM_TESTNET_RPC || '',
            chainId: 41,
            accounts
        },
        telosMainnet: {
            url: process.env.TELOS_EVM_MAINNET_RPC || '',
            chainId: 40,
            accounts
        }
    },
    paths: {
        sources: './contracts',
        tests: './test',
        cache: './cache',
        artifacts: './artifacts'
    }
};

export default config;
