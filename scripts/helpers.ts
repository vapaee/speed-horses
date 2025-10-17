/* eslint-disable @typescript-eslint/no-explicit-any */
import * as fs from 'fs';
import * as path from 'path';
import { BigNumber, ContractTransaction, providers, utils } from 'ethers';

export type LogLine = string;

function pad(value: number): string {
    return String(value).padStart(2, '0');
}

export function nowTs(): string {
    const d = new Date();
    return `${d.getFullYear()}${pad(d.getMonth() + 1)}${pad(d.getDate())}_${pad(d.getHours())}${pad(d.getMinutes())}${pad(d.getSeconds())}`;
}

export function startLogFile(): string {
    const dir = path.resolve('./scripts/logs');
    if (!fs.existsSync(dir)) {
        fs.mkdirSync(dir, { recursive: true });
    }
    const file = path.join(dir, `deployment_${nowTs()}.md`);
    fs.writeFileSync(
        file,
        `# Deployment Log\n\n- Network: \`${process.env.NETWORK_NAME || 'unknown'}\`\n- Timestamp: \`${new Date().toISOString()}\`\n\n`
    );
    return file;
}

export function appendLog(file: string, line: LogLine): void {
    fs.appendFileSync(file, `${line}\n`);
}

export function fmtAddr(label: string, addr: string): string {
    return `- **${label}**: \`${addr}\``;
}

export function fmtBigNumberWeiToTlos(value: BigNumber | string | number): string {
    return utils.formatEther(value);
}

export async function logBalance(
    file: string,
    provider: providers.Provider,
    who: string,
    previous?: BigNumber
): Promise<BigNumber> {
    const balance = await provider.getBalance(who);
    const tlos = fmtBigNumberWeiToTlos(balance);
    if (previous) {
        const currentBigInt = BigInt(balance.toString());
        const previousBigInt = BigInt(previous.toString());
        const diffBigInt = currentBigInt - previousBigInt;
        const sign = diffBigInt > 0n ? '+' : diffBigInt < 0n ? '-' : '';
        const diffAbs = diffBigInt >= 0n ? diffBigInt : -diffBigInt;
        const diffValue = BigNumber.from(diffAbs.toString());
        const tlosDiff = fmtBigNumberWeiToTlos(diffValue);
        appendLog(file, `> **Balance**: \`${tlos} TLOS\`  (**Δ** \`${sign}${tlosDiff} TLOS\`)`);
    } else {
        appendLog(file, `> **Balance**: \`${tlos} TLOS\``);
    }
    return balance;
}

export async function txResult(
    file: string,
    title: string,
    txPromise: Promise<ContractTransaction>
): Promise<void> {
    try {
        const tx = await txPromise;
        const receipt = await tx.wait();
        const hash = receipt?.transactionHash ?? tx.hash;
        const gasUsed = receipt?.gasUsed?.toString();
        appendLog(file, `- ✅ ${title} — tx: \`${hash}\`${gasUsed ? `, gasUsed: \`${gasUsed}\`` : ''}`);
    } catch (err: any) {
        appendLog(file, `- ❌ ${title} — error: \`${err?.message || String(err)}\``);
        throw err;
    }
}
