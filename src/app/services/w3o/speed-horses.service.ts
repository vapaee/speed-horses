// src/app/services/w3o/speed-horses.service.ts

import {
    W3oAccount,
    W3oContext,
    W3oContextFactory,
    W3oInstance,
    W3oModule,
    W3oService,
    W3oAuthenticator,
} from '@vapaee/w3o-core';
import { BehaviorSubject, Observable, Subject, firstValueFrom, from, of } from 'rxjs';
import { catchError, map, tap } from 'rxjs/operators';
import { parseEther } from 'ethers';
import { EthereumTokensService, EthereumNetwork, EthereumTransaction, EthereumContractAbi, EthereumContract } from '@vapaee/w3o-ethereum';



const logger = new W3oContextFactory('SpeedHorsesService');

const FOAL_FORGE_ABI = [
    'function getPendingHorse(address owner) view returns (uint256 imgCategory, uint256 imgNumber, (uint256 power, uint256 acceleration, uint256 stamina, uint256 minSpeed, uint256 maxSpeed, uint256 luck, uint256 curveBonus, uint256 straightBonus) stats, uint256 totalPoints, uint8 extraPackagesBought, (uint256 imgCategory, uint256 imgNumber, (uint256 power, uint256 acceleration, uint256 stamina, uint256 minSpeed, uint256 maxSpeed, uint256 luck, uint256 curveBonus, uint256 straightBonus) bonusStats)[4] horseshoes)',
    'function startHorseMint() payable',
    'function randomizeHorse(bool keepImage, bool keepStats, bool keepShoes) payable',
    'function buyExtraPoints() payable',
    'function claimHorse()'
] as unknown as EthereumContractAbi;

const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000';

const BASE_CREATION_COST = parseEther('600');
const RANDOMIZE_COST = parseEther('100');
const EXTRA_POINTS_COST = parseEther('200');

const DEFAULT_CONTRACT_ADDRESSES: Record<string, string> = {
    '40': ZERO_ADDRESS,
    '41': ZERO_ADDRESS,
};

export interface SpeedHorsesPerformanceStats {
    power: number;
    acceleration: number;
    stamina: number;
    minSpeed: number;
    maxSpeed: number;
    luck: number;
    curveBonus: number;
    straightBonus: number;
}

export interface SpeedHorsesHorseshoe {
    imgCategory: number;
    imgNumber: number;
    bonusStats: SpeedHorsesPerformanceStats;
}

export interface SpeedHorsesFoalData {
    imgCategory: number;
    imgNumber: number;
    stats: SpeedHorsesPerformanceStats;
    totalPoints: number;
    extraPackagesBought: number;
    horseshoes: SpeedHorsesHorseshoe[];
}

export type SpeedHorsesFoal = SpeedHorsesFoalData | null;

export interface SpeedHorsesServiceConfig {
    foalForgeAddresses?: Record<string, string>;
}

export class SpeedHorsesService extends W3oService {
    private readonly contractCache = new Map<string, EthereumContract>();
    private readonly contractAddresses: Record<string, string>;

    tokens!: EthereumTokensService;

    constructor(path: string, config: SpeedHorsesServiceConfig = {}, parent: W3oContext) {
        const context = logger.method('constructor', { path, config }, parent);
        super(path, context);
        this.contractAddresses = { ...DEFAULT_CONTRACT_ADDRESSES, ...(config.foalForgeAddresses ?? {}) };
    }

    get w3oVersion(): string {
        return '1.0.0';
    }

    get w3oName(): string {
        return 'ethereum.service.speed-horses';
    }

    get w3oRequire(): string[] {
        return [
            'ethereum.service.tokens@1.0.0',
        ];
    }

    override init(octopus: W3oInstance, requirements: W3oModule[], parent: W3oContext): void {
        const context = logger.method('init', { octopus, requirements }, parent);
        super.init(octopus, requirements, context);
        console.assert(requirements[0] instanceof EthereumTokensService, 'ERROR: requirements missmatch');
        this.tokens = requirements[0] as EthereumTokensService;
        logger.info('SpeedHorsesService OK!', this.w3oId);
    }

    public getCurrentFoal$(auth: W3oAuthenticator, parent?: W3oContext): BehaviorSubject<SpeedHorsesFoal | null> {
        const context = logger.method('getCurrentFoal$', { auth }, parent);
        const subject = this.getFoalSubject(auth, context);
        this.refreshCurrentFoal(auth, context).subscribe({
            error: error => context.error('getCurrentFoal$ refresh error', error),
        });
        return subject;
    }

    public randomizeFoal(auth: W3oAuthenticator, keepImage: boolean, keepStats: boolean, keepShoes: boolean, parent: W3oContext): Observable<SpeedHorsesFoal> {
        const context = logger.method('randomizeFoal', { keepImage, keepStats, keepShoes }, parent);
        const currentFoal = this.getFoalSubject(auth, context).getValue();
        const transaction: EthereumTransaction = currentFoal
            ? {
                contract: this.getFoalForgeContract(auth, context),
                function: 'randomizeHorse',
                params: { keepImage, keepStats, keepShoes },
                value: RANDOMIZE_COST,
            }
            : {
                contract: this.getFoalForgeContract(auth, context),
                function: 'startHorseMint',
                params: {},
                value: BASE_CREATION_COST,
            };
        return this.executeFoalTransaction(auth, transaction, context);
    }

    public buyExtraPoints(auth: W3oAuthenticator, parent: W3oContext): Observable<SpeedHorsesFoal> {
        const context = logger.method('buyExtraPoints', {}, parent);
        const transaction: EthereumTransaction = {
            contract: this.getFoalForgeContract(auth, context),
            function: 'buyExtraPoints',
            params: {},
            value: EXTRA_POINTS_COST,
        };
        return this.executeFoalTransaction(auth, transaction, context);
    }

    public claimHorse(auth: W3oAuthenticator, parent: W3oContext): Observable<SpeedHorsesFoal> {
        const context = logger.method('claimHorse', {}, parent);
        const transaction: EthereumTransaction = {
            contract: this.getFoalForgeContract(auth, context),
            function: 'claimHorse',
            params: {},
        };
        return this.executeFoalTransaction(auth, transaction, context);
    }

    private executeFoalTransaction(auth: W3oAuthenticator, transaction: EthereumTransaction, parent: W3oContext): Observable<SpeedHorsesFoal> {
        const context = logger.method('executeFoalTransaction', { transaction }, parent);
        const result$ = new Subject<SpeedHorsesFoal>();
        auth.session.signTransaction(transaction, context).subscribe({
            next: (tx: any) => {
                const waitForConfirmation = typeof tx?.wait === 'function'
                    ? tx.wait()
                    : Promise.resolve(undefined);
                waitForConfirmation
                    .then(() => firstValueFrom(this.refreshCurrentFoal(auth, context)))
                    .then(foal => {
                        result$.next(foal);
                        result$.complete();
                    })
                    .catch(error => {
                        context.error('executeFoalTransaction confirmation error', error);
                        result$.error(error);
                    });
            },
            error: (error: unknown) => {
                context.error('executeFoalTransaction sign error', error);
                result$.error(error as Error);
            },
        });
        return result$.asObservable();
    }

    private refreshCurrentFoal(auth: W3oAuthenticator, parent: W3oContext): Observable<SpeedHorsesFoal> {
        const context = logger.method('refreshCurrentFoal', {}, parent);
        const subject = this.getFoalSubject(auth, context);
        const address = auth.session.address;
        if (!address) {
            subject.next(null);
            return of(null);
        }
        return this.fetchCurrentFoal(auth, context).pipe(
            tap(foal => subject.next(foal)),
            catchError(error => {
                context.error('refreshCurrentFoal error', error);
                subject.next(null);
                return of(null);
            })
        );
    }

    private fetchCurrentFoal(auth: W3oAuthenticator, parent: W3oContext): Observable<SpeedHorsesFoal> {
        const address = auth.session.address;
        const context = logger.method('fetchCurrentFoal', {address}, parent);
        if (!address) {
            return of(null);
        }

        const network = this.getEthereumNetwork(auth);
        console.log('fetchCurrentFoal ---- contract.getPendingHorse(address)  ---');
        const contract = this.getFoalForgeContract(auth, context).getReadOnlyContract(network.provider);
        return from(contract.getPendingHorse(address)).pipe(
            tap(raw => console.log('fetchCurrentFoal ---- raw foal ---', {raw})),
            map((raw: any) => this.parseFoal(raw, context)),
            catchError(error => {
                context.error('fetchCurrentFoal error', error);
                return of(null);
            })
        );

    }

    private parseFoal(raw: any, parent: W3oContext): SpeedHorsesFoal | null {
        const context = logger.method('parseFoal', { raw }, parent);
        let result: SpeedHorsesFoal | null = null;
        if (!raw) {
            return result;
        }
        const totalPointsValue = this.toNumber(raw.totalPoints ?? raw[3]);
        if (!totalPointsValue) {
            return result;
        }
        const statsRaw = raw.stats ?? raw[2];
        const horseshoesRaw = raw.horseshoes ?? raw[5] ?? [];
        result = {
            imgCategory: this.toNumber(raw.imgCategory ?? raw[0]),
            imgNumber: this.toNumber(raw.imgNumber ?? raw[1]),
            stats: this.parsePerformanceStats(statsRaw),
            totalPoints: totalPointsValue,
            extraPackagesBought: this.toNumber(raw.extraPackagesBought ?? raw[4]),
            horseshoes: (horseshoesRaw as any[]).map(shoe => this.parseHorseshoe(shoe)),
        };
        context.log('->', { result });
        return result;
    }

    private parseHorseshoe(raw: any): SpeedHorsesHorseshoe {
        return {
            imgCategory: this.toNumber(raw?.imgCategory ?? raw?.[0] ?? 0),
            imgNumber: this.toNumber(raw?.imgNumber ?? raw?.[1] ?? 0),
            bonusStats: this.parsePerformanceStats(raw?.bonusStats ?? raw?.[2] ?? {}),
        };
    }

    private parsePerformanceStats(raw: any): SpeedHorsesPerformanceStats {
        return {
            power: this.toNumber(raw?.power ?? raw?.[0] ?? 0),
            acceleration: this.toNumber(raw?.acceleration ?? raw?.[1] ?? 0),
            stamina: this.toNumber(raw?.stamina ?? raw?.[2] ?? 0),
            minSpeed: this.toNumber(raw?.minSpeed ?? raw?.[3] ?? 0),
            maxSpeed: this.toNumber(raw?.maxSpeed ?? raw?.[4] ?? 0),
            luck: this.toNumber(raw?.luck ?? raw?.[5] ?? 0),
            curveBonus: this.toNumber(raw?.curveBonus ?? raw?.[6] ?? 0),
            straightBonus: this.toNumber(raw?.straightBonus ?? raw?.[7] ?? 0),
        };
    }

    private toNumber(value: any): number {
        if (value == null) {
            return 0;
        }
        if (typeof value === 'bigint') {
            const asNumber = Number(value);
            return Number.isFinite(asNumber) ? asNumber : 0;
        }
        if (typeof value === 'number') {
            return value;
        }
        if (typeof value === 'string') {
            const parsed = Number(value);
            return Number.isFinite(parsed) ? parsed : 0;
        }
        if (typeof (value as { toString?: () => string })?.toString === 'function') {
            try {
                const str = (value as { toString: () => string }).toString();
                const parsed = Number(str);
                return Number.isFinite(parsed) ? parsed : 0;
            } catch (error) {
                void error;
            }
        }
        return 0;
    }

    private getFoalSubject(auth: W3oAuthenticator, parent: W3oContext): BehaviorSubject<SpeedHorsesFoal> {
        const context = logger.method('getFoalSubject', { address: auth.session.address }, parent);
        let subject = auth.session.storage.get('speedHorses.foal$') as BehaviorSubject<SpeedHorsesFoal>;
        if (!subject) {
            subject = new BehaviorSubject<SpeedHorsesFoal>(null);
            auth.session.storage.set('speedHorses.foal$', subject);
        }
        void context;
        return subject;
    }

    private getFoalForgeContract(auth: W3oAuthenticator, parent: W3oContext): EthereumContract {
        const context = logger.method('getFoalForgeContract', {auth}, parent);
        const network = auth.session.network as unknown as EthereumNetwork;
        const chainId = network.ethereumSettings.chainId;
        const cached = this.contractCache.get(chainId);
        if (cached) {
            context.log('Using cached FoalForge contract', { chainId, cached });
            return cached;
        }
        const address = this.contractAddresses[chainId];
        if (!address || address === ZERO_ADDRESS) {
            const error = new Error('FoalForge contract address not configured for chain');
            context.error('FoalForge contract address not configured for chain', { chainId });
            throw error;
        }
        const contract = new EthereumContract(address, 'SpeedH_Minter_FoalForge', FOAL_FORGE_ABI, parent);
        this.contractCache.set(chainId, contract);
        return contract;
    }

    private getEthereumNetwork(auth: W3oAuthenticator): EthereumNetwork {
        const account = auth.account as W3oAccount;
        return account.authenticator.network as unknown as EthereumNetwork;
    }
}
