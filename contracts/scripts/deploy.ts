import * as fs from 'fs';
import { ethers } from 'hardhat';
import { appendLog, startLogFile, fmtAddr, logBalance, txResult } from './helpers';

type DeployedContracts = Record<string, string>;

async function main(): Promise<void> {
    // The script starts by identifying the deployer account and the active blockchain provider.
    // This deployer will be used to sign and broadcast all deployment transactions.
    const [deployer] = await ethers.getSigners();
    const provider = ethers.provider;

    // A new log file is created to track everything that happens during deployment.
    // We also record the deployer’s address and initial balance for reference.
    const logFile = startLogFile();
    appendLog(logFile, '## Deployer');
    appendLog(logFile, `- address: \`${deployer.address}\``);
    let lastBalance = await logBalance(logFile, provider, deployer.address);

    // Now we start the deployment phase.
    // Each contract listed below will be deployed in the given order, and its address stored for later use.
    appendLog(logFile, '\n## Deploy contracts');
    const deployed: DeployedContracts = {};

    const contractsToDeploy = [
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

    // This loop goes one by one through the contract list, deploying each to the blockchain.
    // After each deployment we log its address and the gas cost by comparing the deployer’s balance.
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

    // Once all contracts are deployed, we move on to wiring them together.
    // Here we fetch their instances from the blockchain so we can call configuration functions on them.
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

    // The central Stats contract needs to know who the authorized minters are.
    // Here we grant permission to all three specialized minters.
    await txResult(
        logFile,
        'SpeedH_Stats.setContractMinter(AnvilAlchemy, true)',
        stats.setContractMinter(deployed['SpeedH_Minter_AnvilAlchemy'], true)
    );
    await txResult(
        logFile,
        'SpeedH_Stats.setContractMinter(FoalForge, true)',
        stats.setContractMinter(deployed['SpeedH_Minter_FoalForge'], true)
    );
    await txResult(
        logFile,
        'SpeedH_Stats.setContractMinter(IronRedemption, true)',
        stats.setContractMinter(deployed['SpeedH_Minter_IronRedemption'], true)
    );

    // Now we connect the Stats contract to all other essential modules:
    // the FixtureManager for race events, the HAY token for payments,
    // both NFT contracts, and the two specialized stats contracts.
    await txResult(
        logFile,
        'SpeedH_Stats.setContractFixtureManager(FixtureManager)',
        stats.setContractFixtureManager(deployed['SpeedH_FixtureManager'])
    );
    await txResult(
        logFile,
        'SpeedH_Stats.setContractHayToken(HayToken)',
        stats.setContractHayToken(deployed['SpeedH_HayToken'])
    );
    await txResult(
        logFile,
        'SpeedH_Stats.setContractNFTHorse(NFT_Horse)',
        stats.setContractNFTHorse(deployed['SpeedH_NFT_Horse'])
    );
    await txResult(
        logFile,
        'SpeedH_Stats.setContractNFTHorseshoe(NFT_Horseshoe)',
        stats.setContractNFTHorseshoe(deployed['SpeedH_NFT_Horseshoe'])
    );
    await txResult(
        logFile,
        'SpeedH_Stats.setContractStatsHorse(Stats_Horse)',
        stats.setContractStatsHorse(deployed['SpeedH_Stats_Horse'])
    );
    await txResult(
        logFile,
        'SpeedH_Stats.setContractStatsHorseshoe(Stats_Horseshoe)',
        stats.setContractStatsHorseshoe(deployed['SpeedH_Stats_Horseshoe'])
    );

    // The Stats contract also needs access to metadata managers for visual rendering or data lookup.
    await txResult(
        logFile,
        'SpeedH_Stats.setContractMetadataHorse(Metadata_Horse)',
        stats.setContractMetadataHorse(deployed['SpeedH_Metadata_Horse'])
    );
    await txResult(
        logFile,
        'SpeedH_Stats.setContractMetadataHorseshoe(Metadata_Horseshoe)',
        stats.setContractMetadataHorseshoe(deployed['SpeedH_Metadata_Horseshoe'])
    );

    // Both specialized stats contracts (horse and horseshoe) are given a back reference to the main Stats contract.
    await txResult(
        logFile,
        'SpeedH_Stats_Horseshoe.setContractStats(Stats)',
        statsHorseshoe.setContractStats(deployed['SpeedH_Stats'])
    );
    await txResult(
        logFile,
        'SpeedH_Stats_Horse.setContractStats(Stats)',
        statsHorse.setContractStats(deployed['SpeedH_Stats'])
    );

    // The NFT contracts are also wired to the Stats contract so that minting and game logic remain synchronized.
    // We also authorize the three minters at the NFT level.
    await txResult(
        logFile,
        'SpeedH_NFT_Horse.setContractStats(Stats)',
        nftHorse.setContractStats(deployed['SpeedH_Stats'])
    );
    await txResult(
        logFile,
        'SpeedH_NFT_Horse.setContractMinter(AnvilAlchemy, true)',
        nftHorse.setContractMinter(deployed['SpeedH_Minter_AnvilAlchemy'], true)
    );
    await txResult(
        logFile,
        'SpeedH_NFT_Horse.setContractMinter(FoalForge, true)',
        nftHorse.setContractMinter(deployed['SpeedH_Minter_FoalForge'], true)
    );
    await txResult(
        logFile,
        'SpeedH_NFT_Horse.setContractMinter(IronRedemption, true)',
        nftHorse.setContractMinter(deployed['SpeedH_Minter_IronRedemption'], true)
    );

    // The same setup is applied for the Horseshoe NFT.
    await txResult(
        logFile,
        'SpeedH_NFT_Horseshoe.setContractStats(Stats)',
        nftHorseshoe.setContractStats(deployed['SpeedH_Stats'])
    );
    await txResult(
        logFile,
        'SpeedH_NFT_Horseshoe.setContractMinter(AnvilAlchemy, true)',
        nftHorseshoe.setContractMinter(deployed['SpeedH_Minter_AnvilAlchemy'], true)
    );
    await txResult(
        logFile,
        'SpeedH_NFT_Horseshoe.setContractMinter(FoalForge, true)',
        nftHorseshoe.setContractMinter(deployed['SpeedH_Minter_FoalForge'], true)
    );
    await txResult(
        logFile,
        'SpeedH_NFT_Horseshoe.setContractMinter(IronRedemption, true)',
        nftHorseshoe.setContractMinter(deployed['SpeedH_Minter_IronRedemption'], true)
    );

    // Now each minter contract is configured with the components it interacts with:
    // Stats for logic, NFTs for minting, and HAY for payments.
    await txResult(
        logFile,
        'SpeedH_Minter_IronRedemption.setContractStats(Stats)',
        minterIron.setContractStats(deployed['SpeedH_Stats'])
    );
    await txResult(
        logFile,
        'SpeedH_Minter_IronRedemption.setContractNFTHorseshoe(NFT_Horseshoe)',
        minterIron.setContractNFTHorseshoe(deployed['SpeedH_NFT_Horseshoe'])
    );
    await txResult(
        logFile,
        'SpeedH_Minter_IronRedemption.setContractHayToken(HayToken)',
        minterIron.setContractHayToken(deployed['SpeedH_HayToken'])
    );

    await txResult(
        logFile,
        'SpeedH_Minter_FoalForge.setContractStatsHorse(Stats_Horse)',
        minterFoal.setContractStatsHorse(deployed['SpeedH_Stats_Horse'])
    );
    await txResult(
        logFile,
        'SpeedH_Minter_FoalForge.setContractNFTHorse(NFT_Horse)',
        minterFoal.setContractNFTHorse(deployed['SpeedH_NFT_Horse'])
    );
    await txResult(
        logFile,
        'SpeedH_Minter_FoalForge.setContractNFTHorseshoe(NFT_Horseshoe)',
        minterFoal.setContractNFTHorseshoe(deployed['SpeedH_NFT_Horseshoe'])
    );

    await txResult(
        logFile,
        'SpeedH_Minter_AnvilAlchemy.setContractStats(Stats)',
        minterAnvil.setContractStats(deployed['SpeedH_Stats'])
    );
    await txResult(
        logFile,
        'SpeedH_Minter_AnvilAlchemy.setContractNFTHorseshoe(NFT_Horseshoe)',
        minterAnvil.setContractNFTHorseshoe(deployed['SpeedH_NFT_Horseshoe'])
    );
    await txResult(
        logFile,
        'SpeedH_Minter_AnvilAlchemy.setContractHayToken(HayToken)',
        minterAnvil.setContractHayToken(deployed['SpeedH_HayToken'])
    );

    // Finally, we wire the FixtureManager — the module that handles races —
    // so that it knows where the Stats and HAY contracts are.
    await txResult(
        logFile,
        'SpeedH_FixtureManager.setContractStats(Stats)',
        fixtureManager.setContractStats(deployed['SpeedH_Stats'])
    );
    await txResult(
        logFile,
        'SpeedH_FixtureManager.setContractHayToken(HayToken)',
        fixtureManager.setContractHayToken(deployed['SpeedH_HayToken'])
    );

    // After all configurations, we log the deployer’s final balance to measure total gas spent.
    appendLog(logFile, '\n## Final balance');
    await logBalance(logFile, provider, deployer.address, lastBalance);

    // To close the process, we print the full address book to the log
    // and save all deployed addresses into a JSON file for later use by other scripts or the frontend.
    appendLog(logFile, '\n## Address book');
    for (const [label, address] of Object.entries(deployed)) {
        appendLog(logFile, `- ${label}: \`${address}\``);
    }

    const network = process.env.NETWORK_NAME || 'unknown';
    const addressesPath = `./scripts/addresses.${network}.json`;
    fs.writeFileSync(addressesPath, `${JSON.stringify(deployed, null, 4)}\n`, 'utf8');
    appendLog(logFile, `\n> Addresses JSON written at: \`${addressesPath}\``);
}

// If something goes wrong during the deployment, we print the error and exit with a non-zero code.
main().catch((error) => {
    console.error(error);
    process.exit(1);
});
