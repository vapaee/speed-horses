import { HardhatUserConfig } from 'hardhat/config';
import '@nomicfoundation/hardhat-ethers';
import * as fs from 'fs';
import * as path from 'path';
import * as dotenv from 'dotenv';

dotenv.config();

function readPkFromEnvFile(): string[] {
    const pkFile = process.env.PRIVATE_KEY_FILE;
    if (!pkFile) {
        return [];
    }
    try {
        const raw = fs.readFileSync(path.resolve(pkFile), 'utf8').trim();
        if (!raw) {
            return [];
        }
        const pk = raw.startsWith('0x') ? raw : `0x${raw}`;
        return [pk];
    } catch (error) {
        console.warn(`Could not read PRIVATE_KEY_FILE (${pkFile}):`, error);
        return [];
    }
}

const accounts = readPkFromEnvFile();

const config: HardhatUserConfig = {
    solidity: {
        version: '0.8.24',
        settings: {
            optimizer: { enabled: true, runs: 200 }
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
