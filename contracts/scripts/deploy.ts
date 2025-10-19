// contracts/scripts/deploy.ts
import * as fs from 'fs';
import * as path from 'path';
import { ethers } from 'hardhat';
import { appendLog, startLogFile, fmtAddr, logBalance, txResult } from './helpers';
import { speedHorsesContracts as storedContracts } from '../../src/environments/contracts';

const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000';

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

type ContractName = typeof contractsToDeploy[number];
type ContractAddresses = Record<ContractName, string>;
type DeployedContracts = Partial<ContractAddresses>;

const contractsFilePath = path.resolve(__dirname, '../../src/environments/contracts.ts');

function cloneStoredContracts(): Record<string, Record<string, string>> {
    const clone: Record<string, Record<string, string>> = {};
    for (const [contractName, networks] of Object.entries(storedContracts)) {
        clone[contractName] = { ...networks };
    }
    return clone;
}

function formatContractsFile(contracts: Record<string, Record<string, string>>): string {
    const knownOrder = new Set<string>(contractsToDeploy);
    const orderedContracts = [
        ...contractsToDeploy,
        ...Object.keys(contracts)
            .filter((name) => !knownOrder.has(name))
            .sort((a, b) => a.localeCompare(b)),
    ];
    const lines: string[] = ['export const speedHorsesContracts = {'];
    orderedContracts.forEach((contractName, contractIndex) => {
        const networks = contracts[contractName] ?? {};
        lines.push(`    ${contractName}: {`);
        const networkEntries = Object.entries(networks)
            .sort(([a], [b]) => Number(a) - Number(b));
        networkEntries.forEach(([chainId, address], networkIndex) => {
            const trailingComma = networkIndex < networkEntries.length - 1 ? ',' : '';
            lines.push(`        '${chainId}': '${address}'${trailingComma}`);
        });
        const contractTrailingComma = contractIndex < orderedContracts.length - 1 ? ',' : '';
        lines.push(`    }${contractTrailingComma}`);
    });
    lines.push('};');
    return `${lines.join('\n')}\n`;
}

function failNoDeployer(): never {
    const tips: string[] = [
        'No signer available for the selected network.',
        '',
        'How to fix:',
        '1) Ensure PRIVATE_KEY_FILE is set and points to a readable file with a single private key (no spaces, no quotes).',
        '   Example content: 0x<hex-64>',
        '   Example path:    ./scripts/pk.testnet',
        '2) The key must have funds on the target network (to deploy later).',
        '3) If you see this while running from monorepo root, remember the script runs inside contracts/.',
        '   Try absolute path or verify the relative path is correct.',
        '4) In hardhat.config.ts, accounts are only added if the file is found. If not found, getSigners() is empty.',
        '',
        'Quick checks:',
        '• echo $PRIVATE_KEY_FILE',
        '• ls -l ./contracts/scripts | grep pk',
        '• cat ./contracts/scripts/pk.testnet  (should output a single hex key)',
    ];
    console.error(tips.join('\n'));
    process.exit(1);
}

async function main(): Promise<void> {
    const [deployer] = await ethers.getSigners();
    const provider = ethers.provider;

    if (!deployer) {
        failNoDeployer();
    }

    const logFile = startLogFile();
    appendLog(logFile, '## Deployer');
    appendLog(logFile, `- address: \`${deployer.address}\``);
    let lastBalance = await logBalance(logFile, provider, deployer.address);

    appendLog(logFile, '\n## Deploy contracts');
    const deployed: DeployedContracts = {};
    const resolved: ContractAddresses = {} as ContractAddresses;
    const network = await provider.getNetwork();
    const chainId = network.chainId.toString();

    const storedContractsClone = cloneStoredContracts();

    for (const name of contractsToDeploy) {
        const storedForContract = storedContractsClone[name] ?? {};
        const existingAddress = storedForContract[chainId];

        if (existingAddress && existingAddress !== ZERO_ADDRESS) {
            appendLog(logFile, `\n### Reusing existing \`${name}\``);
            appendLog(logFile, fmtAddr(name, existingAddress));
            resolved[name] = existingAddress;
            continue;
        }

        appendLog(logFile, `\n### Deploy \`${name}\``);
        const factory = await ethers.getContractFactory(name);
        const contract = await factory.deploy();
        await contract.deployed();
        const address = contract.address;
        deployed[name] = address;
        resolved[name] = address;
        appendLog(logFile, fmtAddr(name, address));

        const newBalance = await logBalance(logFile, provider, deployer.address, lastBalance);
        lastBalance = newBalance;

        storedForContract[chainId] = address;
        storedContractsClone[name] = storedForContract;
    }

    for (const name of contractsToDeploy) {
        if (!resolved[name]) {
            const storedForContract = storedContractsClone[name] ?? {};
            const address = storedForContract[chainId];
            if (!address || address === ZERO_ADDRESS) {
                throw new Error(`Contract address for ${name} on chain ${chainId} is missing. Deploy aborted.`);
            }
            resolved[name] = address;
        }
    }

    appendLog(logFile, '\n## Set contract references');

    const stats = await ethers.getContractAt('SpeedH_Stats', resolved['SpeedH_Stats']);
    const statsHorse = await ethers.getContractAt('SpeedH_Stats_Horse', resolved['SpeedH_Stats_Horse']);
    const statsHorseshoe = await ethers.getContractAt('SpeedH_Stats_Horseshoe', resolved['SpeedH_Stats_Horseshoe']);
    const nftHorse = await ethers.getContractAt('SpeedH_NFT_Horse', resolved['SpeedH_NFT_Horse']);
    const nftHorseshoe = await ethers.getContractAt('SpeedH_NFT_Horseshoe', resolved['SpeedH_NFT_Horseshoe']);
    const minterAnvil = await ethers.getContractAt('SpeedH_Minter_AnvilAlchemy', resolved['SpeedH_Minter_AnvilAlchemy']);
    const minterFoal = await ethers.getContractAt('SpeedH_Minter_FoalForge', resolved['SpeedH_Minter_FoalForge']);
    const minterIron = await ethers.getContractAt('SpeedH_Minter_IronRedemption', resolved['SpeedH_Minter_IronRedemption']);
    const fixtureManager = await ethers.getContractAt('SpeedH_FixtureManager', resolved['SpeedH_FixtureManager']);
    const hayToken = await ethers.getContractAt('SpeedH_HayToken', resolved['SpeedH_HayToken']);

    await txResult(logFile, 'SpeedH_Stats.setContractMinter(AnvilAlchemy, true)', stats.setContractMinter(resolved['SpeedH_Minter_AnvilAlchemy'], true));
    await txResult(logFile, 'SpeedH_Stats.setContractMinter(FoalForge, true)', stats.setContractMinter(resolved['SpeedH_Minter_FoalForge'], true));
    await txResult(logFile, 'SpeedH_Stats.setContractMinter(IronRedemption, true)', stats.setContractMinter(resolved['SpeedH_Minter_IronRedemption'], true));

    await txResult(logFile, 'SpeedH_Stats.setContractFixtureManager(FixtureManager)', stats.setContractFixtureManager(resolved['SpeedH_FixtureManager']));
    await txResult(logFile, 'SpeedH_Stats.setContractHayToken(HayToken)', stats.setContractHayToken(resolved['SpeedH_HayToken']));
    await txResult(logFile, 'SpeedH_Stats.setContractNFTHorse(NFT_Horse)', stats.setContractNFTHorse(resolved['SpeedH_NFT_Horse']));
    await txResult(logFile, 'SpeedH_Stats.setContractNFTHorseshoe(NFT_Horseshoe)', stats.setContractNFTHorseshoe(resolved['SpeedH_NFT_Horseshoe']));
    await txResult(logFile, 'SpeedH_Stats.setContractStatsHorse(Stats_Horse)', stats.setContractStatsHorse(resolved['SpeedH_Stats_Horse']));
    await txResult(logFile, 'SpeedH_Stats.setContractStatsHorseshoe(Stats_Horseshoe)', stats.setContractStatsHorseshoe(resolved['SpeedH_Stats_Horseshoe']));

    await txResult(logFile, 'SpeedH_Stats.setContractMetadataHorse(Metadata_Horse)', stats.setContractMetadataHorse(resolved['SpeedH_Metadata_Horse']));
    await txResult(logFile, 'SpeedH_Stats.setContractMetadataHorseshoe(Metadata_Horseshoe)', stats.setContractMetadataHorseshoe(resolved['SpeedH_Metadata_Horseshoe']));

    await txResult(logFile, 'SpeedH_Stats_Horseshoe.setContractStats(Stats)', statsHorseshoe.setContractStats(resolved['SpeedH_Stats']));
    await txResult(logFile, 'SpeedH_Stats_Horse.setContractStats(Stats)', statsHorse.setContractStats(resolved['SpeedH_Stats']));

    await txResult(logFile, 'SpeedH_NFT_Horse.setContractStats(Stats)', nftHorse.setContractStats(resolved['SpeedH_Stats']));
    await txResult(logFile, 'SpeedH_NFT_Horse.setContractMinter(AnvilAlchemy, true)', nftHorse.setContractMinter(resolved['SpeedH_Minter_AnvilAlchemy'], true));
    await txResult(logFile, 'SpeedH_NFT_Horse.setContractMinter(FoalForge, true)', nftHorse.setContractMinter(resolved['SpeedH_Minter_FoalForge'], true));
    await txResult(logFile, 'SpeedH_NFT_Horse.setContractMinter(IronRedemption, true)', nftHorse.setContractMinter(resolved['SpeedH_Minter_IronRedemption'], true));

    await txResult(logFile, 'SpeedH_NFT_Horseshoe.setContractStats(Stats)', nftHorseshoe.setContractStats(resolved['SpeedH_Stats']));
    await txResult(logFile, 'SpeedH_NFT_Horseshoe.setContractMinter(AnvilAlchemy, true)', nftHorseshoe.setContractMinter(resolved['SpeedH_Minter_AnvilAlchemy'], true));
    await txResult(logFile, 'SpeedH_NFT_Horseshoe.setContractMinter(FoalForge, true)', nftHorseshoe.setContractMinter(resolved['SpeedH_Minter_FoalForge'], true));
    await txResult(logFile, 'SpeedH_NFT_Horseshoe.setContractMinter(IronRedemption, true)', nftHorseshoe.setContractMinter(resolved['SpeedH_Minter_IronRedemption'], true));

    await txResult(logFile, 'SpeedH_Minter_IronRedemption.setContractStats(Stats)', minterIron.setContractStats(resolved['SpeedH_Stats']));
    await txResult(logFile, 'SpeedH_Minter_IronRedemption.setContractNFTHorseshoe(NFT_Horseshoe)', minterIron.setContractNFTHorseshoe(resolved['SpeedH_NFT_Horseshoe']));
    await txResult(logFile, 'SpeedH_Minter_IronRedemption.setContractHayToken(HayToken)', minterIron.setContractHayToken(resolved['SpeedH_HayToken']));

    await txResult(logFile, 'SpeedH_Minter_FoalForge.setContractStats(Stats)', minterFoal.setContractStats(resolved['SpeedH_Stats']));
    await txResult(logFile, 'SpeedH_Minter_FoalForge.setContractNFTHorse(NFT_Horse)', minterFoal.setContractNFTHorse(resolved['SpeedH_NFT_Horse']));
    await txResult(logFile, 'SpeedH_Minter_FoalForge.setContractNFTHorseshoe(NFT_Horseshoe)', minterFoal.setContractNFTHorseshoe(resolved['SpeedH_NFT_Horseshoe']));

    await txResult(logFile, 'SpeedH_Minter_AnvilAlchemy.setContractStats(Stats)', minterAnvil.setContractStats(resolved['SpeedH_Stats']));
    await txResult(logFile, 'SpeedH_Minter_AnvilAlchemy.setContractNFTHorseshoe(NFT_Horseshoe)', minterAnvil.setContractNFTHorseshoe(resolved['SpeedH_NFT_Horseshoe']));
    await txResult(logFile, 'SpeedH_Minter_AnvilAlchemy.setContractHayToken(HayToken)', minterAnvil.setContractHayToken(resolved['SpeedH_HayToken']));

    await txResult(logFile, 'SpeedH_FixtureManager.setContractStats(Stats)', fixtureManager.setContractStats(resolved['SpeedH_Stats']));
    await txResult(logFile, 'SpeedH_FixtureManager.setContractHayToken(HayToken)', fixtureManager.setContractHayToken(resolved['SpeedH_HayToken']));

    appendLog(logFile, '\n## Final balance');
    await logBalance(logFile, provider, deployer.address, lastBalance);

    appendLog(logFile, '\n## Address book');
    for (const [label, address] of Object.entries(resolved)) {
        appendLog(logFile, `- ${label}: \`${address}\``);
    }

    const networkName = process.env.NETWORK_NAME || 'unknown';
    const addressesPath = `./scripts/addresses.${networkName}.json`;
    fs.writeFileSync(addressesPath, `${JSON.stringify(resolved, null, 4)}\n`, 'utf8');
    appendLog(logFile, `\n> Addresses JSON written at: \`${addressesPath}\``);

    for (const name of contractsToDeploy) {
        const networks = storedContractsClone[name] ?? {};
        storedContractsClone[name] = {
            ...networks,
            [chainId]: resolved[name],
        };
    }

    const formattedContracts = formatContractsFile(storedContractsClone);
    fs.writeFileSync(contractsFilePath, formattedContracts, 'utf8');
    appendLog(logFile, `> Updated contracts file at: \`${contractsFilePath}\``);
}

main().catch((error) => {
    console.error(error);
    process.exit(1);
});