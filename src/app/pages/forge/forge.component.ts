// src/app/pages/home/home.component.ts
import { Component, OnInit } from '@angular/core';
import { HorseshoeComponent } from '@app/components/horseshoe/horseshoe.component';
import { LockSwitchComponent } from '@app/components/lock-switch/lock-switch.component';
import { StatsComponent } from '@app/components/stats/stats.component';
import { SharedModule } from '@app/shared/shared.module';
import { StatsPack } from '@app/types';
import { TranslateService } from '@ngx-translate/core';
import { ToggleButtonModule } from 'primeng/togglebutton';
import { ToggleSwitchModule } from 'primeng/toggleswitch';

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
export class ForgePage implements OnInit {
    totalPoints = 60;
    color = "black";
    name = "Speedy Gonzales";
    baseStats: StatsPack;
    horseshoes: StatsPack[];
    shuffle_horseshoes = true;
    shuffle_basestats = true;
    shuffle_picture = true;

    constructor(
        private translate: TranslateService,
    ){}

    ngOnInit(): void {
        this.buildStats();

        // Optional: rebuild labels if language changes
        this.translate.onLangChange.subscribe(() => {
            this.buildStats();
        });
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
}
