import { HardhatUserConfig, configVariable } from 'hardhat/config';
import '@nomicfoundation/hardhat-ethers';
import * as fs from 'fs';
import * as path from 'path';
import * as dotenv from 'dotenv';
import { fileURLToPath } from 'url';
import type { HttpNetworkUserConfig } from 'hardhat/types';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const envFiles = [
    path.join(__dirname, '.env'),
    path.join(__dirname, '..', '.env')
];

for (const envFile of envFiles) {
    if (fs.existsSync(envFile)) {
        dotenv.config({ path: envFile });
    }
}

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
        } catch (error) {
            // Try the next candidate
        }
    }

    return [];
};

const accounts = readAccounts();

const createHttpNetworkConfig = (chainId: number, rpcEnvVar: string): HttpNetworkUserConfig => ({
    type: 'http',
    chainId,
    url: configVariable(rpcEnvVar, '{variable}'),
    ...(accounts.length > 0 ? { accounts } : {})
});

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
