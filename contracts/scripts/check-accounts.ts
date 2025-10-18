// contracts/scripts/check-accounts.ts
import { ethers } from 'hardhat';

async function main(): Promise<void> {
    const signers = await ethers.getSigners();
    console.log('signers:', signers.map(s => s.address));
}
main();
