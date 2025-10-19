// contracts/scripts/test-deployment.ts
import { ethers } from 'hardhat';
import { speedHorsesContracts } from '../../src/environments/contracts';

const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000';

const contractNames = [
    'SpeedH_FixtureManager',
    'SpeedH_HayToken',
    'SpeedH_Metadata_Horse',
    'SpeedH_Metadata_Horseshoe',
    'SpeedH_Minter_AnvilAlchemy',
    'SpeedH_Minter_FoalForge',
    'SpeedH_Minter_IronRedemption',
    'SpeedH_NFT_Horse',
    'SpeedH_NFT_Horseshoe',
    'SpeedH_Stats_Horse',
    'SpeedH_Stats_Horseshoe',
    'SpeedH_Stats'
] as const;

type ContractName = typeof contractNames[number];
type ContractAddressBook = Record<ContractName, string>;

const toChecksum = (address: string): string => ethers.utils.getAddress(address);

const success = (message: string): void => {
    console.log(`✅ ${message}`);
};

const fail = (context: string, expected: string, received: string): never => {
    throw new Error(`❌ ${context} — expected: ${expected}, received: ${received}`);
};

const assertAddress = async (
    label: string,
    getter: () => Promise<string>,
    expected: string
): Promise<void> => {
    const value = toChecksum(await getter());
    if (value !== expected) {
        fail(label, expected, value);
    }
    success(`${label} → ${value}`);
};

const assertBoolTrue = async (label: string, getter: () => Promise<boolean>): Promise<void> => {
    const value = await getter();
    if (!value) {
        fail(label, 'true', String(value));
    }
    success(`${label} → true`);
};

async function main(): Promise<void> {
    const provider = ethers.provider;
    const network = await provider.getNetwork();
    const chainId = network.chainId.toString();
    const networkName = process.env.NETWORK_NAME || network.name || 'unknown';

    console.log('--- Speed Horses deployment check ---');
    console.log(`Network: ${networkName} (chainId: ${chainId})`);

    const addresses: Partial<ContractAddressBook> = {};

    for (const name of contractNames) {
        const networks = speedHorsesContracts[name];
        const stored = networks?.[chainId];
        if (!stored || stored === ZERO_ADDRESS) {
            throw new Error(`Missing address for ${name} on chain ${chainId}. Please run the deployment first.`);
        }
        const checksum = toChecksum(stored);
        addresses[name] = checksum;
        console.log(`- ${name}: ${checksum}`);
    }

    const resolved = addresses as ContractAddressBook;

    console.log('\nVerifying SpeedH_Stats references...');
    const stats = await ethers.getContractAt('SpeedH_Stats', resolved.SpeedH_Stats);
    await assertBoolTrue('SpeedH_Stats.isHorseMinter(AnvilAlchemy)', () =>
        stats.isHorseMinter(resolved.SpeedH_Minter_AnvilAlchemy)
    );
    await assertBoolTrue('SpeedH_Stats.isHorseMinter(FoalForge)', () =>
        stats.isHorseMinter(resolved.SpeedH_Minter_FoalForge)
    );
    await assertBoolTrue('SpeedH_Stats.isHorseMinter(IronRedemption)', () =>
        stats.isHorseMinter(resolved.SpeedH_Minter_IronRedemption)
    );
    await assertAddress('SpeedH_Stats._contractFixtureManager', () => stats._contractFixtureManager(), resolved.SpeedH_FixtureManager);
    await assertAddress('SpeedH_Stats._contractHayToken', () => stats._contractHayToken(), resolved.SpeedH_HayToken);
    await assertAddress('SpeedH_Stats._contractNFTHorse', () => stats._contractNFTHorse(), resolved.SpeedH_NFT_Horse);
    await assertAddress('SpeedH_Stats._contractNFTHorseshoe', () => stats._contractNFTHorseshoe(), resolved.SpeedH_NFT_Horseshoe);
    await assertAddress('SpeedH_Stats._contractStatsHorse', () => stats._contractStatsHorse(), resolved.SpeedH_Stats_Horse);
    await assertAddress('SpeedH_Stats._contractStatsHorseshoe', () => stats._contractStatsHorseshoe(), resolved.SpeedH_Stats_Horseshoe);
    await assertAddress('SpeedH_Stats._contractMetadataHorse', () => stats._contractMetadataHorse(), resolved.SpeedH_Metadata_Horse);
    await assertAddress('SpeedH_Stats._contractMetadataHorseshoe', () => stats._contractMetadataHorseshoe(), resolved.SpeedH_Metadata_Horseshoe);

    console.log('\nVerifying module contracts...');
    const statsHorse = await ethers.getContractAt('SpeedH_Stats_Horse', resolved.SpeedH_Stats_Horse);
    await assertAddress('SpeedH_Stats_Horse._contractStats', () => statsHorse._contractStats(), resolved.SpeedH_Stats);
    const statsHorseshoe = await ethers.getContractAt('SpeedH_Stats_Horseshoe', resolved.SpeedH_Stats_Horseshoe);
    await assertAddress('SpeedH_Stats_Horseshoe._contractStats', () => statsHorseshoe._contractStats(), resolved.SpeedH_Stats);

    console.log('\nVerifying NFT contracts...');
    const nftHorse = await ethers.getContractAt('SpeedH_NFT_Horse', resolved.SpeedH_NFT_Horse);
    await assertAddress('SpeedH_NFT_Horse._contractStats', () => nftHorse._contractStats(), resolved.SpeedH_Stats);
    await assertBoolTrue('SpeedH_NFT_Horse.isHorseMinter(AnvilAlchemy)', () =>
        nftHorse.isHorseMinter(resolved.SpeedH_Minter_AnvilAlchemy)
    );
    await assertBoolTrue('SpeedH_NFT_Horse.isHorseMinter(FoalForge)', () =>
        nftHorse.isHorseMinter(resolved.SpeedH_Minter_FoalForge)
    );
    await assertBoolTrue('SpeedH_NFT_Horse.isHorseMinter(IronRedemption)', () =>
        nftHorse.isHorseMinter(resolved.SpeedH_Minter_IronRedemption)
    );

    const nftHorseshoe = await ethers.getContractAt('SpeedH_NFT_Horseshoe', resolved.SpeedH_NFT_Horseshoe);
    await assertAddress('SpeedH_NFT_Horseshoe._contractStats', () => nftHorseshoe._contractStats(), resolved.SpeedH_Stats);
    await assertBoolTrue('SpeedH_NFT_Horseshoe.isHorseMinter(AnvilAlchemy)', () =>
        nftHorseshoe.isHorseMinter(resolved.SpeedH_Minter_AnvilAlchemy)
    );
    await assertBoolTrue('SpeedH_NFT_Horseshoe.isHorseMinter(FoalForge)', () =>
        nftHorseshoe.isHorseMinter(resolved.SpeedH_Minter_FoalForge)
    );
    await assertBoolTrue('SpeedH_NFT_Horseshoe.isHorseMinter(IronRedemption)', () =>
        nftHorseshoe.isHorseMinter(resolved.SpeedH_Minter_IronRedemption)
    );

    console.log('\nVerifying minter contracts...');
    const minterIron = await ethers.getContractAt('SpeedH_Minter_IronRedemption', resolved.SpeedH_Minter_IronRedemption);
    await assertAddress('SpeedH_Minter_IronRedemption._contractStats', () => minterIron._contractStats(), resolved.SpeedH_Stats);
    await assertAddress('SpeedH_Minter_IronRedemption._contractNFTHorseshoe', () => minterIron._contractNFTHorseshoe(), resolved.SpeedH_NFT_Horseshoe);
    await assertAddress('SpeedH_Minter_IronRedemption._contractHayToken', () => minterIron._contractHayToken(), resolved.SpeedH_HayToken);

    const minterFoal = await ethers.getContractAt('SpeedH_Minter_FoalForge', resolved.SpeedH_Minter_FoalForge);
    await assertAddress('SpeedH_Minter_FoalForge._contractStatsHorse', () => minterFoal._contractStatsHorse(), resolved.SpeedH_Stats_Horse);
    await assertAddress('SpeedH_Minter_FoalForge._contractNFTHorse', () => minterFoal._contractNFTHorse(), resolved.SpeedH_NFT_Horse);
    await assertAddress('SpeedH_Minter_FoalForge._contractNFTHorseshoe', () => minterFoal._contractNFTHorseshoe(), resolved.SpeedH_NFT_Horseshoe);

    const minterAnvil = await ethers.getContractAt('SpeedH_Minter_AnvilAlchemy', resolved.SpeedH_Minter_AnvilAlchemy);
    await assertAddress('SpeedH_Minter_AnvilAlchemy._contractStats', () => minterAnvil._contractStats(), resolved.SpeedH_Stats);
    await assertAddress('SpeedH_Minter_AnvilAlchemy._contractNFTHorseshoe', () => minterAnvil._contractNFTHorseshoe(), resolved.SpeedH_NFT_Horseshoe);
    await assertAddress('SpeedH_Minter_AnvilAlchemy._contractHayToken', () => minterAnvil._contractHayToken(), resolved.SpeedH_HayToken);

    console.log('\nVerifying fixture manager...');
    const fixtureManager = await ethers.getContractAt('SpeedH_FixtureManager', resolved.SpeedH_FixtureManager);
    await assertAddress('SpeedH_FixtureManager._contractStats', () => fixtureManager._contractStats(), resolved.SpeedH_Stats);
    await assertAddress('SpeedH_FixtureManager._contractHayToken', () => fixtureManager._contractHayToken(), resolved.SpeedH_HayToken);

    console.log('\nAll contract references match the expected deployment addresses.');
}

main().catch((error) => {
    console.error(error);
    process.exit(1);
});
