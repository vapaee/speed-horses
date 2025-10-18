// 4 spaces indent, vars/comments in English, single quotes
import * as fs from 'fs';
import * as path from 'path';
import { fileURLToPath } from 'url';
import { ethers } from 'ethers';

export type LogLine = string;

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const pad = (value: number): string => String(value).padStart(2, '0');

export const nowTs = (): string => {
    const date = new Date();
    return `${date.getFullYear()}${pad(date.getMonth() + 1)}${pad(date.getDate())}_${pad(date.getHours())}${pad(date.getMinutes())}${pad(date.getSeconds())}`;
};

export const startLogFile = (): string => {
    const directory = path.resolve(__dirname, 'logs');
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

export const fmtBigintWeiToTlos = (value: string | number | ethers.BigNumber): string => {
    return utils.formatEther(value);
};

export const logBalance = async (
    filePath: string,
    provider: providers.Provider,
    account: string,
    previous?: ethers.BigNumber
): Promise<ethers.BigNumber> => {
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
