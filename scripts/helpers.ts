/* eslint-disable @typescript-eslint/no-explicit-any */
import * as fs from 'fs';
import * as path from 'path';
import { AbstractProvider, ContractTransactionResponse, formatEther } from 'ethers';

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

export function fmtBigintWeiToTlos(v: bigint): string {
    return formatEther(v);
}

export async function logBalance(
    file: string,
    provider: AbstractProvider,
    who: string,
    previous?: bigint
): Promise<bigint> {
    const balance = await provider.getBalance(who);
    const tlos = fmtBigintWeiToTlos(balance);
    if (typeof previous === 'bigint') {
        const diff = balance - previous;
        const sign = diff > 0n ? '+' : '';
        const tlosDiff = fmtBigintWeiToTlos(diff);
        appendLog(file, `> **Balance**: \`${tlos} TLOS\`  (**Δ** \`${sign}${tlosDiff} TLOS\`)`);
    } else {
        appendLog(file, `> **Balance**: \`${tlos} TLOS\``);
    }
    return balance;
}

export async function txResult(
    file: string,
    title: string,
    txPromise: Promise<ContractTransactionResponse>
): Promise<void> {
    try {
        const tx = await txPromise;
        const receipt = await tx.wait();
        const hash = receipt?.hash ?? tx.hash;
        const gasUsed = receipt?.gasUsed?.toString();
        appendLog(file, `- ✅ ${title} — tx: \`${hash}\`${gasUsed ? `, gasUsed: \`${gasUsed}\`` : ''}`);
    } catch (err: any) {
        appendLog(file, `- ❌ ${title} — error: \`${err?.message || String(err)}\``);
        throw err;
    }
}
