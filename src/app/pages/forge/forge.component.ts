// src/app/pages/home/home.component.ts
import { Component, OnDestroy, OnInit } from '@angular/core';
import { HorseshoeComponent } from '@app/components/horseshoe/horseshoe.component';
import { LockSwitchComponent } from '@app/components/lock-switch/lock-switch.component';
import { StatsComponent } from '@app/components/stats/stats.component';
import { SharedModule } from '@app/shared/shared.module';
import { StatsPack } from '@app/types';
import { SessionService } from '@app/services/session-kit.service';
import { Web3OctopusService } from '@app/services/web3-octopus.service';
import { SpeedHorsesService } from '@app/services/w3o/speed-horses.service';
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
    baseStats: StatsPack;
    horseshoes: StatsPack[];
    lock_horseshoes = false;
    lock_basestats = false;
    lock_picture = false;
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
                return;
            }
            const service = this.getSpeedHorsesService();
            const context = this.logger.method('subscribeFoal', { address: session.address });
            this.foalSub = service.getCurrentFoal$(session.authenticator, context).subscribe(foal => {
                console.log('[ForgePage] current foal', foal);
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
        const power = this.translate.instant('PROPERTIES.power');
        const acceleration = this.translate.instant('PROPERTIES.acceleration');
        const stamina = this.translate.instant('PROPERTIES.stamina');
        const minSpeed = this.translate.instant('PROPERTIES.minSpeed');
        const maxSpeed = this.translate.instant('PROPERTIES.maxSpeed');
        const luck = this.translate.instant('PROPERTIES.luck');
        const curveBonus = this.translate.instant('PROPERTIES.curveBonus');
        const straightBonus = this.translate.instant('PROPERTIES.straightBonus');

        this.baseStats = {
            total: 60,
            stats: [
                { field: 'power', display: power, value: 20},
                { field: 'acceleration', display: acceleration, value: 10},
                { field: 'stamina', display: stamina, value: 30},
                { field: 'minSpeed', display: minSpeed, value: 10},
                { field: 'maxSpeed', display: maxSpeed, value: 20},
                { field: 'luck', display: luck, value: 60},
                { field: 'curveBonus', display: curveBonus, value: 50},
                { field: 'straightBonus', display: straightBonus, value: 40},
            ]
        };

        this.horseshoes = [
            {
                total: 10,
                stats: [
                    { field: 'power', display: power, value: 8},
                    { field: 'acceleration', display: acceleration, value: 2}
                ]
            },
            {
                total: 10,
                stats: [
                    { field: 'stamina', display: stamina, value: 3},
                    { field: 'maxSpeed', display: maxSpeed, value: 7},
                ]
            },
            {
                total: 12,
                stats: [
                    { field: 'luck', display: luck, value: 8},
                    { field: 'curveBonus', display: curveBonus, value: 4}
                ]
            },
            {
                total: 10,
                stats: [
                    { field: 'minSpeed', display: minSpeed, value: 6},
                    { field: 'straightBonus', display: straightBonus, value: 4}
                ]
            },
        ]

    }

    onRandomizeFoal(): void {
        this.withAuth(
            'onRandomizeFoal',
            { keepImage: this.lock_picture, keepStats: this.lock_basestats, keepShoes: this.lock_horseshoes },
            (service, auth, context) => {
                service.randomizeFoal(auth, this.lock_picture, this.lock_basestats, this.lock_horseshoes, context).subscribe({
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
        this.withAuth('onClaimHorse', {}, (service, auth, context) => {
            service.claimHorse(auth, context).subscribe({
                next: foal => console.log('[ForgePage] claimHorse result', foal),
                error: error => context.error('claimHorse error', error),
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
}
