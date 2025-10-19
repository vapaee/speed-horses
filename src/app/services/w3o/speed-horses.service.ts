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
import { BehaviorSubject, Observable, from, isObservable, of, throwError } from 'rxjs';
import { catchError, map, switchMap, tap } from 'rxjs/operators';
import { parseEther } from 'ethers';
import { EthereumTokensService, EthereumNetwork, EthereumTransaction, EthereumContractAbi, EthereumContract } from '@vapaee/w3o-ethereum';



const logger = new W3oContextFactory('SpeedHorsesService');

// TODO: remove one of the two definitions below
// const FOAL_FORGE_ABI = [
//     'function getPendingHorse(address owner) view returns (uint256 imgCategory, uint256 imgNumber, (uint256 power, uint256 acceleration, uint256 stamina, uint256 minSpeed, uint256 maxSpeed, uint256 luck, uint256 curveBonus, uint256 straightBonus) stats, uint256 totalPoints, uint8 extraPackagesBought, (uint256 imgCategory, uint256 imgNumber, (uint256 power, uint256 acceleration, uint256 stamina, uint256 minSpeed, uint256 maxSpeed, uint256 luck, uint256 curveBonus, uint256 straightBonus) bonusStats)[4] horseshoes)',
//     'function startHorseMint() payable',
//     'function randomizeHorse(bool keepImage, bool keepStats, bool keepShoes) payable',
//     'function buyExtraPoints() payable',
//     'function claimHorse()'
// ] as unknown as EthereumContractAbi;

/**
 * Structured ABI for the Foal Forge contract
 * - Replaces string-based fragments with explicit ABI items
 * - Tuples are represented with `type: 'tuple'` and `components`
 * - Fixed-size tuple array `[4]` is represented as `type: 'tuple[4]'`
 */
export const FOAL_FORGE_ABI: EthereumContractAbi = [
    {
        type: 'function',
        name: 'getPendingHorse',
        stateMutability: 'view',
        inputs: [
            { name: 'owner', type: 'address' }
        ],
        outputs: [
            // uint256 imgCategory
            { name: 'imgCategory', type: 'uint256' },
            // uint256 imgNumber
            { name: 'imgNumber', type: 'uint256' },
            // (PerformanceStats) stats
            {
                name: 'stats',
                type: 'tuple',
                components: [
                    { name: 'power', type: 'uint256' },
                    { name: 'acceleration', type: 'uint256' },
                    { name: 'stamina', type: 'uint256' },
                    { name: 'minSpeed', type: 'uint256' },
                    { name: 'maxSpeed', type: 'uint256' },
                    { name: 'luck', type: 'uint256' },
                    { name: 'curveBonus', type: 'uint256' },
                    { name: 'straightBonus', type: 'uint256' }
                ]
            },
            // uint256 totalPoints
            { name: 'totalPoints', type: 'uint256' },
            // uint8 extraPackagesBought
            { name: 'extraPackagesBought', type: 'uint8' },
            // (Horseshoe tuple)[4] horseshoes
            {
                name: 'horseshoes',
                type: 'tuple[4]',
                components: [
                    { name: 'imgCategory', type: 'uint256' },
                    { name: 'imgNumber', type: 'uint256' },
                    {
                        name: 'bonusStats',
                        type: 'tuple',
                        components: [
                            { name: 'power', type: 'uint256' },
                            { name: 'acceleration', type: 'uint256' },
                            { name: 'stamina', type: 'uint256' },
                            { name: 'minSpeed', type: 'uint256' },
                            { name: 'maxSpeed', type: 'uint256' },
                            { name: 'luck', type: 'uint256' },
                            { name: 'curveBonus', type: 'uint256' },
                            { name: 'straightBonus', type: 'uint256' }
                        ]
                    }
                ]
            }
        ]
    },
    {
        type: 'function',
        name: 'startHorseMint',
        stateMutability: 'payable',
        inputs: [],
        outputs: []
    },
    {
        type: 'function',
        name: 'randomizeHorse',
        stateMutability: 'payable',
        inputs: [
            { name: 'keepImage', type: 'bool' },
            { name: 'keepStats', type: 'bool' },
            { name: 'keepShoes', type: 'bool' }
        ],
        outputs: []
    },
    {
        type: 'function',
        name: 'buyExtraPoints',
        stateMutability: 'payable',
        inputs: [],
        outputs: []
    },
    {
        type: 'function',
        name: 'claimHorse',
        stateMutability: 'nonpayable',
        inputs: [],
        outputs: []
    }
] as const;


const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000';

const BASE_CREATION_COST = parseEther('600');
const RANDOMIZE_COST = parseEther('100');
const EXTRA_POINTS_COST = parseEther('200');

// action="estimateGas",
// data="0x23019e67",
// reason=null,
// transaction={ 
//    "data": "0xdf10eb22",
//    "from": "0xa30b5e3c8Fee56C135Aecb733cd708cC31A5657a",
//    "to": "0xbd0641B448241adb16935A1cBa3ffBB936D32b87"
// },
// invocation=null,
// revert=null,
// code=CALL_EXCEPTION,
// version=6.15.0


/*
speed-horses.service.ts:231 ERRORS:  0x7bfa4b9f NotAdmin()
speed-horses.service.ts:231 ERRORS:  0x4245fe6a InvalidStatsAddress()
speed-horses.service.ts:231 ERRORS:  0xa01f5e19 InvalidHayToken()
speed-horses.service.ts:231 ERRORS:  0x2d494867 HorseStatsNotSet()
speed-horses.service.ts:231 ERRORS:  0x710541c3 HayTokenNotSet()
speed-horses.service.ts:231 ERRORS:  0xaf16090f IncompleteHorseshoes()
speed-horses.service.ts:231 ERRORS:  0x404383bf HorseshoeWornOut()
speed-horses.service.ts:231 ERRORS:  0xd1cb4145 HorseAlreadyRegistered()
speed-horses.service.ts:231 ERRORS:  0x738a10fb FusionNotFound()
speed-horses.service.ts:231 ERRORS:  0xb5eba9f0 InvalidAdmin()
speed-horses.service.ts:231 ERRORS:  0xbb739137 InvalidErrorMargin()
speed-horses.service.ts:231 ERRORS:  0xa14f2d38 InvalidRefundBps()
speed-horses.service.ts:231 ERRORS:  0xf4d678b8 InsufficientBalance()
speed-horses.service.ts:231 ERRORS:  0xbbb196a3 HayTransferFailed()
speed-horses.service.ts:231 ERRORS:  0xc37bc9f7 StatsNotSet()
speed-horses.service.ts:231 ERRORS:  0x3ffef675 NftNotSet()
speed-horses.service.ts:231 ERRORS:  0xcd0dee6d IncorrectTlosPayment()
speed-horses.service.ts:231 ERRORS:  0xfd9f2811 SameParents()
speed-horses.service.ts:231 ERRORS:  0xfef69c94 InvalidParents()
speed-horses.service.ts:231 ERRORS:  0xc35265ce ParentsEquipped()
speed-horses.service.ts:231 ERRORS:  0x140aaf2c FatherNotApproved()
speed-horses.service.ts:231 ERRORS:  0xf5cb95a6 MotherNotApproved()
speed-horses.service.ts:231 ERRORS:  0xacf3f60e FusionFinalized()
speed-horses.service.ts:231 ERRORS:  0xb30184b6 FusionAlreadyProcessed()
speed-horses.service.ts:231 ERRORS:  0x6a09f224 NotFusionOwner()
speed-horses.service.ts:231 ERRORS:  0xbfa79c68 HayNotSet()
speed-horses.service.ts:231 ERRORS:  0xc67e3e6c HayPaymentFailed()
speed-horses.service.ts:231 ERRORS:  0xff9c7448 PreviewMissing()
speed-horses.service.ts:231 ERRORS:  0xc32a2424 RepairNotFound()
speed-horses.service.ts:231 ERRORS:  0xb92e9c7a InvalidPercent()
speed-horses.service.ts:231 ERRORS:  0xa61eaf53 UnknownHorseshoe()
speed-horses.service.ts:231 ERRORS:  0xf93c59ba HorseshoeEquipped()
speed-horses.service.ts:231 ERRORS:  0x1dcbd64c ApprovalMissing()
speed-horses.service.ts:231 ERRORS:  0x3c347266 RepairFinalized()
speed-horses.service.ts:231 ERRORS:  0x437cc199 RepairAlreadyProcessed()
speed-horses.service.ts:231 ERRORS:  0xb05e4ade NotRepairOwner()
speed-horses.service.ts:231 ERRORS:  0x50a8b861 NotHorseMinter()
speed-horses.service.ts:231 ERRORS:  0xd8d5894f InvalidMinter()
speed-horses.service.ts:231 ERRORS:  0xceea21b6 TokenDoesNotExist()
speed-horses.service.ts:231 ERRORS:  0xd1924e00 HorseStillResting()
speed-horses.service.ts:231 ERRORS:  0x32948259 HorseRegisteredForRacing()
speed-horses.service.ts:231 ERRORS:  0x8c56836d NotFixtureManager()
speed-horses.service.ts:231 ERRORS:  0xd92e233d ZeroAddress()
speed-horses.service.ts:231 ERRORS:  0x960d8bf9 HorseModuleNotSet()
speed-horses.service.ts:231 ERRORS:  0xa7c3fd69 HorseshoeModuleNotSet()
speed-horses.service.ts:231 ERRORS:  0x746feca3 HorseTokenNotSet()
speed-horses.service.ts:231 ERRORS:  0xff21653b TokensNotConfigured()
speed-horses.service.ts:231 ERRORS:  0x10053c99 NothingToAssign()
speed-horses.service.ts:231 ERRORS:  0x30f978b8 NotHorseOwner()
speed-horses.service.ts:231 ERRORS:  0xdf7e698a NotHorseshoeOwner()
speed-horses.service.ts:231 ERRORS:  0x2e53a303 AlreadyEquipped()
speed-horses.service.ts:231 ERRORS:  0xbca4cf23 HorseshoeInUse()
speed-horses.service.ts:231 ERRORS:  0x53f83c73 HorseshoeNotUseful()
speed-horses.service.ts:231 ERRORS:  0x848084dd SlotsFull()
speed-horses.service.ts:231 ERRORS:  0x6e378ef7 MismatchedOwner()
speed-horses.service.ts:231 ERRORS:  0xe0926a1c NotEquipped()
speed-horses.service.ts:231 ERRORS:  0x7cc0e99f HorseRegistered()
speed-horses.service.ts:231 ERRORS:  0x2c5211c6 InvalidAmount()
speed-horses.service.ts:231 ERRORS:  0xba45dca4 NoHorseshoesEquipped()
speed-horses.service.ts:231 ERRORS:  0xfa1b1d38 HorseMetadataNotSet()
speed-horses.service.ts:231 ERRORS:  0x1c7ab172 HorseshoeMetadataNotSet()
speed-horses.service.ts:231 ERRORS:  0x30cd7471 NotOwner()
speed-horses.service.ts:231 ERRORS:  0x23019e67 NotController()
speed-horses.service.ts:231 ERRORS:  0x6d5769be InvalidController()
speed-horses.service.ts:231 ERRORS:  0x49e27cff InvalidOwner()
speed-horses.service.ts:231 ERRORS:  0x0782b0c0 HorseAlreadyExists()
speed-horses.service.ts:231 ERRORS:  0xd848afdb InvalidImage()
speed-horses.service.ts:231 ERRORS:  0x3a0c4e6d HorseNotFound()
speed-horses.service.ts:231 ERRORS:  0x303e7a07 InsufficientPoints()
speed-horses.service.ts:231 ERRORS:  0x0716f3ca HorseshoeAlreadyExists()
speed-horses.service.ts:231 ERRORS:  0x7a8f6411 InvalidDurability()
speed-horses.service.ts:231 ERRORS:  0xecff7d7c HorseshoeNotFound()
speed-horses.service.ts:231 ERRORS:  0x97ead703 InsufficientDurability()
speed-horses.service.ts:231 ERRORS:  0xe2277121 NoCategories()
speed-horses.service.ts:231 ERRORS:  0xc1b1ccaf CategoriesEmpty()
speed-horses.service.ts:231 ERRORS:  0x3df99dee InvalidSelection()

*/


// Genera selectores de tus custom errors
import { keccak256, toUtf8Bytes } from 'ethers';

const errorSigs = [
    'NotAdmin()',
    'InvalidStatsAddress()',
    'InvalidHayToken()',
    'HorseStatsNotSet()',
    'HayTokenNotSet()',
    'IncompleteHorseshoes()',
    'HorseshoeWornOut()',
    'HorseAlreadyRegistered()',
    'FusionNotFound()',
    'InvalidAdmin()',
    'InvalidErrorMargin()',
    'InvalidRefundBps()',
    'InsufficientBalance()',
    'HayTransferFailed()',
    'StatsNotSet()',
    'NftNotSet()',
    'IncorrectTlosPayment()',
    'SameParents()',
    'InvalidParents()',
    'ParentsEquipped()',
    'FatherNotApproved()',
    'MotherNotApproved()',
    'FusionFinalized()',
    'FusionAlreadyProcessed()',
    'NotFusionOwner()',
    'HayNotSet()',
    'HayPaymentFailed()',
    'PreviewMissing()',
    'RepairNotFound()',
    'InvalidPercent()',
    'UnknownHorseshoe()',
    'HorseshoeEquipped()',
    'ApprovalMissing()',
    'RepairFinalized()',
    'RepairAlreadyProcessed()',
    'NotRepairOwner()',
    'NotHorseMinter()',
    'InvalidMinter()',
    'TokenDoesNotExist()',
    'HorseStillResting()',
    'HorseRegisteredForRacing()',
    'NotFixtureManager()',
    'ZeroAddress()',
    'HorseModuleNotSet()',
    'HorseshoeModuleNotSet()',
    'HorseTokenNotSet()',
    'TokensNotConfigured()',
    'NothingToAssign()',
    'NotHorseOwner()',
    'NotHorseshoeOwner()',
    'AlreadyEquipped()',
    'HorseshoeInUse()',
    'HorseshoeNotUseful()',
    'SlotsFull()',
    'MismatchedOwner()',
    'NotEquipped()',
    'HorseRegistered()',
    'InvalidAmount()',
    'NoHorseshoesEquipped()',
    'HorseMetadataNotSet()',
    'HorseshoeMetadataNotSet()',
    'NotOwner()',
    'NotController()',
    'InvalidController()',
    'InvalidOwner()',
    'HorseAlreadyExists()',
    'InvalidImage()',
    'HorseNotFound()',
    'InsufficientPoints()',
    'HorseshoeAlreadyExists()',
    'InvalidDurability()',
    'HorseshoeNotFound()',
    'InsufficientDurability()',
    'NoCategories()',
    'CategoriesEmpty()',
    'InvalidSelection()',
];

for (const sig of errorSigs) {
    const selector = keccak256(toUtf8Bytes(sig)).slice(0, 10);
    console.log('ERRORS: ', selector, sig);
}



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
    SpeedH_FixtureManager?: Record<string, string>;
    SpeedH_HayToken?: Record<string, string>;
    SpeedH_Metadata_Horse?: Record<string, string>;
    SpeedH_Metadata_Horseshoe?: Record<string, string>;
    SpeedH_Minter_AnvilAlchemy?: Record<string, string>;
    SpeedH_Minter_FoalForge?: Record<string, string>;
    SpeedH_Minter_IronRedemption?: Record<string, string>;
    SpeedH_NFT_Horse?: Record<string, string>;
    SpeedH_NFT_Horseshoe?: Record<string, string>;
    SpeedH_Stats_Horse?: Record<string, string>;
    SpeedH_Stats_Horseshoe?: Record<string, string>;
    SpeedH_Stats?: Record<string, string>;
}

export class SpeedHorsesService extends W3oService {
    private readonly contractCache = new Map<string, EthereumContract>();
    private readonly contractAddresses: Record<string, string>;

    tokens!: EthereumTokensService;

    constructor(path: string, config: SpeedHorsesServiceConfig = {}, parent: W3oContext) {
        const context = logger.method('constructor', { path, config }, parent);
        super(path, context);
        this.contractAddresses = { ...(config.SpeedH_Minter_FoalForge ?? {}) };
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

        return auth.session.signTransaction(transaction, context).pipe(
            catchError(error => {
                context.error('executeFoalTransaction sign error', error);
                return throwError(() => error);
            }),
            switchMap((tx: any) => {
                let wait$: Observable<unknown>;

                // try to wait for transaction confirmation
                if (typeof tx?.wait === 'function') {
                    try {
                        const waitResult = tx.wait();
                        if (isObservable(waitResult)) {
                            // Observable
                            wait$ = waitResult;
                        } else if (waitResult && typeof waitResult.then === 'function') {
                            // Promiseish
                            wait$ = from(waitResult);
                        } else {
                            // We don't know
                            wait$ = of(waitResult);
                        }
                    } catch (error) {
                        context.error('executeFoalTransaction wait error', error);
                        return throwError(() => error);
                    }
                } else {
                    // no wait function
                    wait$ = of(undefined);
                }

                return wait$.pipe(
                    switchMap(() => this.refreshCurrentFoal(auth, context)),
                    catchError(error => {
                        context.error('executeFoalTransaction confirmation error', error);
                        return throwError(() => error);
                    }),
                );
            }),
        );
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
        const context = logger.method('parseFoal', { raw, totalPoints: raw.totalPoints, raw_3: raw[3] }, parent);
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
        console.log('--------------------', {address}, '--------------------');
        const contract = new EthereumContract(address, 'SpeedH_Minter_FoalForge', FOAL_FORGE_ABI, parent);
        this.contractCache.set(chainId, contract);
        return contract;
    }

    private getEthereumNetwork(auth: W3oAuthenticator): EthereumNetwork {
        const account = auth.account as W3oAccount;
        return account.authenticator.network as unknown as EthereumNetwork;
    }
}
