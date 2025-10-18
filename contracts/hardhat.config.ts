// 4 spaces indent, English names/comments, single quotes
import { HardhatUserConfig } from 'hardhat/config';
import '@nomiclabs/hardhat-ethers';
import * as fs from 'fs';
import * as path from 'path';
import * as dotenv from 'dotenv';
import type { HttpNetworkUserConfig } from 'hardhat/types';

const here = __dirname;
const envFiles = [path.join(here, '.env'), path.join(here, '..', '.env')];
for (const envFile of envFiles) {
    if (fs.existsSync(envFile)) {
        dotenv.config({ path: envFile });
    }
}

const DEFAULT_RPCS = {
    TELOS_EVM_TESTNET_RPC: 'https://rpc.testnet.telos.net',
    TELOS_EVM_MAINNET_RPC: 'https://rpc.telos.net'
};
const envOrDefault = (name: keyof typeof DEFAULT_RPCS): string =>
    (process.env[name] && process.env[name]!.trim()) || DEFAULT_RPCS[name];

const readAccounts = (): string[] => {
    const pkFile = process.env.PRIVATE_KEY_FILE;
    if (!pkFile) {
        return [];
    }
    const candidates = [
        path.resolve(process.cwd(), pkFile),
        path.resolve(here, pkFile)
    ];
    for (const c of candidates) {
        try {
            const raw = fs.readFileSync(c, 'utf8').trim();
            if (!raw) {
                continue;
            }
            return [raw.startsWith('0x') ? raw : `0x${raw}`];
        } catch {
            // try next
        }
    }
    return [];
};
const accounts = readAccounts();

const createHttpNetworkConfig = (chainId: number, rpcEnvVar: keyof typeof DEFAULT_RPCS): HttpNetworkUserConfig => ({
    chainId,
    url: envOrDefault(rpcEnvVar),
    accounts: accounts.length > 0 ? accounts : undefined
});

const config: HardhatUserConfig = {
    solidity: {
        version: '0.8.24',
        settings: {
            optimizer: { enabled: true, runs: 200 },
            viaIR: true     // <— enable IR to fix "Stack too deep"
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
