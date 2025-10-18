// 4 spaces indent, English names/comments, single quotes
import * as fs from 'fs';
import * as path from 'path';
import { utils, providers, ContractTransaction, BigNumber } from 'ethers';

type LogLine = string;

// Works in both CJS and ESM transpiled outputs
const getHere = (): string => {
    // __dirname exists in CJS, which is your current setup
    return __dirname;
};

const here = getHere();

const pad = (value: number): string => String(value).padStart(2, '0');

export const nowTs = (): string => {
    const date = new Date();
    return `${date.getFullYear()}${pad(date.getMonth() + 1)}${pad(date.getDate())}_${pad(date.getHours())}${pad(date.getMinutes())}${pad(date.getSeconds())}`;
};

export const startLogFile = (): string => {
    const directory = path.resolve(here, 'logs');
    if (!fs.existsSync(directory)) {
        fs.mkdirSync(directory, { recursive: true });
    }
    const filePath = path.join(directory, `deployment_${nowTs()}.md`);
    const header = [
        '# Deployment Log',
        '',
        `- Network: \`${process.env.NETWORK_NAME || 'unknown'}\``,
        `- Timestamp: \`${new Date().toISOString()}\``,
        '',
        ''
    ].join('\n');
    fs.writeFileSync(filePath, header);
    return filePath;
};

export const appendLog = (filePath: string, line: LogLine): void => {
    fs.appendFileSync(filePath, `${line}\n`);
};

export const fmtAddr = (label: string, address: string): string => `- **${label}**: \`${address}\``;

export const fmtBigintWeiToTlos = (value: BigNumber): string => {
    return utils.formatEther(value);
};

export const logBalance = async (
    filePath: string,
    provider: providers.Provider,
    account: string,
    previous?: BigNumber
): Promise<BigNumber> => {
    const balance = await provider.getBalance(account);
    const humanReadable = utils.formatEther(balance);
    if (previous !== undefined) {
        const diff = balance.sub(previous);
        const sign = diff.gt(0) ? '+' : '';
        const diffHuman = utils.formatEther(diff);
        appendLog(filePath, `> **Balance**: \`${humanReadable} TLOS\`  (**Δ** \`${sign}${diffHuman} TLOS\`)`);
    } else {
        appendLog(filePath, `> **Balance**: \`${humanReadable} TLOS\``);
    }
    return balance;
};

export const txResult = async (
    filePath: string,
    title: string,
    txPromise: Promise<ContractTransaction>
): Promise<void> => {
    try {
        const tx = await txPromise;
        const receipt = await tx.wait();
        const gasUsed = receipt && receipt.gasUsed ? receipt.gasUsed.toString() : 'n/a';
        appendLog(filePath, `- ✅ ${title} — tx: \`${tx.hash}\`, gasUsed: \`${gasUsed}\``);
    } catch (error) {
        const message = error instanceof Error ? error.message : String(error);
        appendLog(filePath, `- ❌ ${title} — error: \`${message}\``);
        throw error;
    }
};
