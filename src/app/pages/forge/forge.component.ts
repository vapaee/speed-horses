// src/app/pages/home/home.component.ts
import { Component, OnDestroy, OnInit } from '@angular/core';
import { HorseshoeComponent } from '@app/components/horseshoe/horseshoe.component';
import { LockSwitchComponent } from '@app/components/lock-switch/lock-switch.component';
import { StatsComponent } from '@app/components/stats/stats.component';
import { SharedModule } from '@app/shared/shared.module';
import { StatsPack } from '@app/types';
import { SessionService } from '@app/services/session-kit.service';
import { Web3OctopusService } from '@app/services/web3-octopus.service';
import { SpeedHorsesFoal, SpeedHorsesPerformanceStats, SpeedHorsesService } from '@app/services/w3o/speed-horses.service';
import { TranslateService } from '@ngx-translate/core';
import { ToggleButtonModule } from 'primeng/togglebutton';
import { ToggleSwitchModule } from 'primeng/toggleswitch';
import { Subscription } from 'rxjs';
import { W3oAuthenticator, W3oContext, W3oContextFactory } from '@vapaee/w3o-core';

@Component({
    standalone: true,
    selector: 'app-forge',
    imports: [
        SharedModule,
        StatsComponent,
        HorseshoeComponent,
        ToggleButtonModule,
        ToggleSwitchModule,
        LockSwitchComponent
    ],
    templateUrl: './forge.component.html',
    styleUrls: ['./forge.component.scss']
})
export class ForgePage implements OnInit, OnDestroy {
    totalPoints = 60;
    color = "black";
    name = "Speedy Gonzales";
    horseStats?: StatsPack;
    horseshoes: StatsPack[] = [];
    lock_horseshoes = false;
    lock_stats = false;
    lock_picture = false;
    summonConfirmVisible = false;
    viewState: 'default' | 'current' | 'success' = 'default';
    private currentFoal: SpeedHorsesFoal = null;
    private successFoal: SpeedHorsesFoal = null;
    private pendingClaimFoal: SpeedHorsesFoal = null;
    private readonly statKeys: (keyof SpeedHorsesPerformanceStats)[] = [
        'power',
        'acceleration',
        'stamina',
        'minSpeed',
        'maxSpeed',
        'luck',
        'curveBonus',
        'straightBonus',
    ];
    private statLabels: Partial<Record<keyof SpeedHorsesPerformanceStats, string>> = {};
    private readonly logger = new W3oContextFactory('ForgePage');
    private sessionSub?: Subscription;
    private foalSub?: Subscription;

    constructor(
        private translate: TranslateService,
        private sessionService: SessionService,
        private web3o: Web3OctopusService,
    ){}

    ngOnInit(): void {
        this.buildStats();

        this.sessionSub = this.sessionService.session$.subscribe(session => {
            this.foalSub?.unsubscribe();
            if (!session || session.network.type !== 'ethereum') {
                this.currentFoal = null;
                this.successFoal = null;
                this.updateFoalData(null);
                this.updateViewState();
                return;
            }
            const service = this.getSpeedHorsesService();
            this.foalSub = service.getCurrentFoal$(session.authenticator).subscribe(foal => {
                this.logger.log('[ForgePage] current foal', foal);
                this.currentFoal = foal;
                if (foal) {
                    this.successFoal = null;
                }
                this.updateFoalData(foal);
                this.updateViewState();
            });
        });

        // Optional: rebuild labels if language changes
        this.translate.onLangChange.subscribe(() => {
            this.buildStats();
        });
    }

    ngOnDestroy(): void {
        this.sessionSub?.unsubscribe();
        this.foalSub?.unsubscribe();
    }

    private buildStats(): void {
        // Use translate.instant for static labels of the tab bar
        const labels: Partial<Record<keyof SpeedHorsesPerformanceStats, string>> = {};
        for (const key of this.statKeys) {
            labels[key] = this.translate.instant(`PROPERTIES.${key}`);
        }
        this.statLabels = labels;
        this.updateFoalData(this.currentFoal);
    }

    onRandomizeFoal(): void {
        this.withAuth(
            'onRandomizeFoal',
            { keepImage: this.lock_picture, keepStats: this.lock_stats, keepShoes: this.lock_horseshoes },
            (service, auth, context) => {
                service.randomizeFoal(auth, this.lock_picture, this.lock_stats, this.lock_horseshoes, context).subscribe({
                    next: foal => console.log('[ForgePage] randomizeFoal result', foal),
                    error: error => context.error('randomizeFoal error', error),
                });
            }
        );
    }

    onBuyExtraPoints(): void {
        this.withAuth('onBuyExtraPoints', {}, (service, auth, context) => {
            service.buyExtraPoints(auth, context).subscribe({
                next: foal => console.log('[ForgePage] buyExtraPoints result', foal),
                error: error => context.error('buyExtraPoints error', error),
            });
        });
    }

    onClaimHorse(): void {
        const currentFoal = this.currentFoal;
        this.withAuth('onClaimHorse', {}, (service, auth, context) => {
            this.pendingClaimFoal = currentFoal;
            service.claimHorse(auth, context).subscribe({
                next: foal => {
                    console.log('[ForgePage] claimHorse result', foal);
                    const claimed = this.pendingClaimFoal ?? foal ?? null;
                    if (claimed) {
                        this.successFoal = claimed;
                    }
                    this.pendingClaimFoal = null;
                    this.updateViewState();
                },
                error: error => {
                    context.error('claimHorse error', error);
                    this.pendingClaimFoal = null;
                },
            });
        });
    }

    onSummonFoal(): void {
        this.summonConfirmVisible = true;
    }

    onCancelSummon(): void {
        this.summonConfirmVisible = false;
    }

    onConfirmSummon(): void {
        this.summonConfirmVisible = false;
        this.withAuth('onSummonFoal', {}, (service, auth, context) => {
            service.randomizeFoal(auth, false, false, false, context).subscribe({
                next: foal => {
                    console.log('[ForgePage] summonFoal result', foal);
                    this.successFoal = null;
                },
                error: error => context.error('summonFoal error', error),
            });
        });
    }

    private withAuth(
        label: string,
        extra: Record<string, unknown>,
        handler: (service: SpeedHorsesService, auth: W3oAuthenticator, context: W3oContext) => void
    ): void {
        const session = this.sessionService.current;
        const context = this.logger.method(label, { address: session?.address, ...extra });
        if (!session || session.network.type !== 'ethereum') {
            context.warn('Ethereum session required for Speed Horses actions');
            return;
        }
        const service = this.getSpeedHorsesService();
        handler(service, session.authenticator, context);
    }

    private getSpeedHorsesService(): SpeedHorsesService {
        return this.web3o.octopus.services.ethereum.speedhorses;
    }

    private updateFoalData(foal: SpeedHorsesFoal): void {
        if (!foal) {
            this.horseStats = undefined;
            this.horseshoes = [];
            return;
        }
        this.horseStats = {
            total: foal.totalPoints,
            stats: this.buildPerformanceStats(foal.stats),
        };
        this.horseshoes = (foal.horseshoes ?? []).map(shoe => ({
            total: this.calculateTotal(shoe.bonusStats),
            stats: this.buildPerformanceStats(shoe.bonusStats),
        }));
    }

    private buildPerformanceStats(stats: SpeedHorsesPerformanceStats): { field: string; value: number; display: string }[] {
        return this.statKeys.map(key => ({
            field: key,
            display: this.statLabels[key] ?? key,
            value: Number(stats[key] ?? 0),
        }));
    }

    private calculateTotal(stats: SpeedHorsesPerformanceStats): number {
        return Object.values(stats).reduce((acc, value) => acc + Number(value ?? 0), 0);
    }

    private updateViewState(): void {
        if (this.currentFoal) {
            this.viewState = 'current';
            return;
        }
        if (this.successFoal) {
            this.viewState = 'success';
            return;
        }
        this.viewState = 'default';
    }

    get claimedFoal(): SpeedHorsesFoal | null {
        return this.successFoal;
    }

    get claimedStats(): StatsPack | undefined {
        const foal = this.claimedFoal;
        if (!foal) {
            return undefined;
        }
        return {
            total: foal.totalPoints,
            stats: this.buildPerformanceStats(foal.stats),
        };
    }

    get claimedHorseshoes(): StatsPack[] {
        const foal = this.claimedFoal;
        if (!foal) {
            return [];
        }
        return (foal.horseshoes ?? []).map(shoe => ({
            total: this.calculateTotal(shoe.bonusStats),
            stats: this.buildPerformanceStats(shoe.bonusStats),
        }));
    }

    onDismissSuccess(): void {
        this.successFoal = null;
        this.updateViewState();
    }
}
