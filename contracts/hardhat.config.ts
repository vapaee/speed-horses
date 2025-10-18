// 4 spaces indent, vars/comments in English, single quotes
import { HardhatUserConfig } from 'hardhat/config';
import '@nomiclabs/hardhat-ethers';
import * as fs from 'fs';
import * as path from 'path';
import * as dotenv from 'dotenv';
import { fileURLToPath } from 'url';
import type { HttpNetworkUserConfig } from 'hardhat/types';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Load .env (local) and parent .env (monorepo)
const envFiles = [
    path.join(__dirname, '.env'),
    path.join(__dirname, '..', '.env')
];

for (const envFile of envFiles) {
    if (fs.existsSync(envFile)) {
        dotenv.config({ path: envFile });
    }
}

// Small helper to fail fast when an env var is missing
const requireEnv = (name: string): string => {
    const v = process.env[name];
    if (!v) {
        throw new Error(`Missing required env var: ${name}`);
    }
    return v;
};

const readAccounts = (): string[] => {
    const pkFile = process.env.PRIVATE_KEY_FILE;
    if (!pkFile) {
        return [];
    }

    const candidates = [
        path.resolve(process.cwd(), pkFile),
        path.resolve(__dirname, pkFile)
    ];

    for (const candidate of candidates) {
        try {
            const raw = fs.readFileSync(candidate, 'utf8').trim();
            if (!raw) {
                continue;
            }
            return [raw.startsWith('0x') ? raw : `0x${raw}`];
        } catch {
            // Try next candidate
        }
    }

    return [];
};

const accounts = readAccounts();

const createHttpNetworkConfig = (chainId: number, rpcEnvVar: string): HttpNetworkUserConfig => ({
    chainId,
    url: requireEnv(rpcEnvVar),
    accounts: accounts.length > 0 ? accounts : undefined
});

const config: HardhatUserConfig = {
    solidity: {
        version: '0.8.24',
        settings: {
            optimizer: { enabled: true, runs: 200 }
        }
    },
    networks: {
        telosTestnet: createHttpNetworkConfig(41, 'TELOS_EVM_TESTNET_RPC'),
        telosMainnet: createHttpNetworkConfig(40, 'TELOS_EVM_MAINNET_RPC')
    },
    paths: {
        sources: './src',
        tests: './test',
        cache: './cache',
        artifacts: './artifacts'
    }
};

export default config;
