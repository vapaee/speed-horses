/* eslint-disable @typescript-eslint/no-explicit-any */
// Indentation 4 spaces, single quotes, braces always, comments and names in English.

import { ethers } from 'hardhat';
import { writeFile } from 'fs/promises';
import { appendLog, startLogFile, fmtAddr, logBalance, txResult } from './helpers';

type Deployed = Record<string, string>;

type ContractName =
    | 'SpeedH_FixtureManager'
    | 'SpeedH_HayToken'
    | 'SpeedH_Metadata_Horse'
    | 'SpeedH_Metadata_Horseshoe'
    | 'SpeedH_Minter_AnvilAlchemy'
    | 'SpeedH_Minter_FoalForge'
    | 'SpeedH_Minter_IronRedemption'
    | 'SpeedH_NFT_Horse'
    | 'SpeedH_NFT_Horseshoe'
    | 'SpeedH_Stats_Horse'
    | 'SpeedH_Stats_Horseshoe'
    | 'SpeedH_Stats';

const contractsToDeploy: ContractName[] = [
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
];

async function main(): Promise<void> {
    const [deployer] = await ethers.getSigners();
    const provider = ethers.provider;

    const logFile = startLogFile();

    appendLog(logFile, '## Deployer');
    appendLog(logFile, `- address: \`${deployer.address}\``);
    let lastBalance = await logBalance(logFile, provider, deployer.address);

    appendLog(logFile, '\n## Deploy contracts');
    const deployed: Deployed = {};

    for (const name of contractsToDeploy) {
        appendLog(logFile, `\n### Deploy \`${name}\``);
        const factory = await ethers.getContractFactory(name);
        const contract = await factory.deploy();
        await contract.waitForDeployment();
        const address = await contract.getAddress();
        deployed[name] = address;
        appendLog(logFile, fmtAddr(name, address));

        const newBalance = await logBalance(logFile, provider, deployer.address, lastBalance);
        lastBalance = newBalance;
    }

    appendLog(logFile, '\n## Set contract references');

    const stats = await ethers.getContractAt('SpeedH_Stats', deployed['SpeedH_Stats']);
    const statsHorse = await ethers.getContractAt('SpeedH_Stats_Horse', deployed['SpeedH_Stats_Horse']);
    const statsHorseshoe = await ethers.getContractAt('SpeedH_Stats_Horseshoe', deployed['SpeedH_Stats_Horseshoe']);
    const nftHorse = await ethers.getContractAt('SpeedH_NFT_Horse', deployed['SpeedH_NFT_Horse']);
    const nftHorseshoe = await ethers.getContractAt('SpeedH_NFT_Horseshoe', deployed['SpeedH_NFT_Horseshoe']);
    const minterAnvil = await ethers.getContractAt('SpeedH_Minter_AnvilAlchemy', deployed['SpeedH_Minter_AnvilAlchemy']);
    const minterFoal = await ethers.getContractAt('SpeedH_Minter_FoalForge', deployed['SpeedH_Minter_FoalForge']);
    const minterIron = await ethers.getContractAt('SpeedH_Minter_IronRedemption', deployed['SpeedH_Minter_IronRedemption']);
    const fixtureManager = await ethers.getContractAt('SpeedH_FixtureManager', deployed['SpeedH_FixtureManager']);
    const hayToken = await ethers.getContractAt('SpeedH_HayToken', deployed['SpeedH_HayToken']);

    await txResult(logFile, 'SpeedH_Stats.setContractMinter(AnvilAlchemy, true)',
        stats.setContractMinter(deployed['SpeedH_Minter_AnvilAlchemy'], true)
    );
    await txResult(logFile, 'SpeedH_Stats.setContractMinter(FoalForge, true)',
        stats.setContractMinter(deployed['SpeedH_Minter_FoalForge'], true)
    );
    await txResult(logFile, 'SpeedH_Stats.setContractMinter(IronRedemption, true)',
        stats.setContractMinter(deployed['SpeedH_Minter_IronRedemption'], true)
    );
    await txResult(logFile, 'SpeedH_Stats.setContractFixtureManager(FixtureManager)',
        stats.setContractFixtureManager(deployed['SpeedH_FixtureManager'])
    );
    await txResult(logFile, 'SpeedH_Stats.setContractHayToken(HayToken)',
        stats.setContractHayToken(deployed['SpeedH_HayToken'])
    );
    await txResult(logFile, 'SpeedH_Stats.setContractNFTHorse(NFT_Horse)',
        stats.setContractNFTHorse(deployed['SpeedH_NFT_Horse'])
    );
    await txResult(logFile, 'SpeedH_Stats.setContractNFTHorseshoe(NFT_Horseshoe)',
        stats.setContractNFTHorseshoe(deployed['SpeedH_NFT_Horseshoe'])
    );
    await txResult(logFile, 'SpeedH_Stats.setContractStatsHorse(Stats_Horse)',
        stats.setContractStatsHorse(deployed['SpeedH_Stats_Horse'])
    );
    await txResult(logFile, 'SpeedH_Stats.setContractStatsHorseshoe(Stats_Horseshoe)',
        stats.setContractStatsHorseshoe(deployed['SpeedH_Stats_Horseshoe'])
    );
    await txResult(logFile, 'SpeedH_Stats.setContractMetadataHorse(Metadata_Horse)',
        stats.setContractMetadataHorse(deployed['SpeedH_Metadata_Horse'])
    );
    await txResult(logFile, 'SpeedH_Stats.setContractMetadataHorseshoe(Metadata_Horseshoe)',
        stats.setContractMetadataHorseshoe(deployed['SpeedH_Metadata_Horseshoe'])
    );

    await txResult(logFile, 'SpeedH_Stats_Horseshoe.setContractStats(Stats)',
        statsHorseshoe.setContractStats(deployed['SpeedH_Stats'])
    );

    await txResult(logFile, 'SpeedH_Stats_Horse.setContractStats(Stats)',
        statsHorse.setContractStats(deployed['SpeedH_Stats'])
    );

    await txResult(logFile, 'SpeedH_NFT_Horse.setContractStats(Stats)',
        nftHorse.setContractStats(deployed['SpeedH_Stats'])
    );
    await txResult(logFile, 'SpeedH_NFT_Horse.setContractMinter(AnvilAlchemy, true)',
        nftHorse.setContractMinter(deployed['SpeedH_Minter_AnvilAlchemy'], true)
    );
    await txResult(logFile, 'SpeedH_NFT_Horse.setContractMinter(FoalForge, true)',
        nftHorse.setContractMinter(deployed['SpeedH_Minter_FoalForge'], true)
    );
    await txResult(logFile, 'SpeedH_NFT_Horse.setContractMinter(IronRedemption, true)',
        nftHorse.setContractMinter(deployed['SpeedH_Minter_IronRedemption'], true)
    );

    await txResult(logFile, 'SpeedH_NFT_Horseshoe.setContractStats(Stats)',
        nftHorseshoe.setContractStats(deployed['SpeedH_Stats'])
    );
    await txResult(logFile, 'SpeedH_NFT_Horseshoe.setContractMinter(AnvilAlchemy, true)',
        nftHorseshoe.setContractMinter(deployed['SpeedH_Minter_AnvilAlchemy'], true)
    );
    await txResult(logFile, 'SpeedH_NFT_Horseshoe.setContractMinter(FoalForge, true)',
        nftHorseshoe.setContractMinter(deployed['SpeedH_Minter_FoalForge'], true)
    );
    await txResult(logFile, 'SpeedH_NFT_Horseshoe.setContractMinter(IronRedemption, true)',
        nftHorseshoe.setContractMinter(deployed['SpeedH_Minter_IronRedemption'], true)
    );

    await txResult(logFile, 'SpeedH_Minter_IronRedemption.setContractStats(Stats)',
        minterIron.setContractStats(deployed['SpeedH_Stats'])
    );
    await txResult(logFile, 'SpeedH_Minter_IronRedemption.setContractNFTHorseshoe(NFT_Horseshoe)',
        minterIron.setContractNFTHorseshoe(deployed['SpeedH_NFT_Horseshoe'])
    );
    await txResult(logFile, 'SpeedH_Minter_IronRedemption.setContractHayToken(HayToken)',
        minterIron.setContractHayToken(deployed['SpeedH_HayToken'])
    );

    await txResult(logFile, 'SpeedH_Minter_FoalForge.setContractStatsHorse(Stats_Horse)',
        minterFoal.setContractStatsHorse(deployed['SpeedH_Stats_Horse'])
    );
    await txResult(logFile, 'SpeedH_Minter_FoalForge.setContractNFTHorse(NFT_Horse)',
        minterFoal.setContractNFTHorse(deployed['SpeedH_NFT_Horse'])
    );
    await txResult(logFile, 'SpeedH_Minter_FoalForge.setContractNFTHorseshoe(NFT_Horseshoe)',
        minterFoal.setContractNFTHorseshoe(deployed['SpeedH_NFT_Horseshoe'])
    );

    await txResult(logFile, 'SpeedH_Minter_AnvilAlchemy.setContractStats(Stats)',
        minterAnvil.setContractStats(deployed['SpeedH_Stats'])
    );
    await txResult(logFile, 'SpeedH_Minter_AnvilAlchemy.setContractNFTHorseshoe(NFT_Horseshoe)',
        minterAnvil.setContractNFTHorseshoe(deployed['SpeedH_NFT_Horseshoe'])
    );
    await txResult(logFile, 'SpeedH_Minter_AnvilAlchemy.setContractHayToken(HayToken)',
        minterAnvil.setContractHayToken(deployed['SpeedH_HayToken'])
    );

    await txResult(logFile, 'SpeedH_FixtureManager.setContractStats(Stats)',
        fixtureManager.setContractStats(deployed['SpeedH_Stats'])
    );
    await txResult(logFile, 'SpeedH_FixtureManager.setContractHayToken(HayToken)',
        fixtureManager.setContractHayToken(deployed['SpeedH_HayToken'])
    );

    appendLog(logFile, '\n## Final balance');
    await logBalance(logFile, provider, deployer.address, lastBalance);

    appendLog(logFile, '\n## Address book');
    Object.entries(deployed).forEach(([name, address]) => {
        appendLog(logFile, `- ${name}: \`${address}\``);
    });

    const network = process.env.NETWORK_NAME || 'unknown';
    const jsonPath = `./scripts/addresses.${network}.json`;
    await writeFile(jsonPath, JSON.stringify(deployed, null, 4), 'utf8');
    appendLog(logFile, `\n> Addresses JSON written at: \`${jsonPath}\``);
}

main().catch((err) => {
    console.error(err);
    process.exit(1);
});
