// src/app/pages/home/home.component.ts
import { Component } from '@angular/core';
import { SharedModule } from '@app/shared/shared.module';
import { LucideAngularModule } from 'lucide-angular';

@Component({
    standalone: true,
    selector: 'app-home',
    imports: [SharedModule, LucideAngularModule],
    template: `
        <div class="p-home">
            <div class="p-home__header">
                <img class="p-home__logo" src="assets/images/gold-horse.png" alt="speed horses" />
                <div class="p-home__title">{{ 'PAGES.HOME.TITLE' | translate }}</div>
            </div>
            <p class="p-home__subtitle">{{ 'PAGES.HOME.DESCRIPTION' | translate }}</p>
            <div class="p-home__on-telos">
                {{ 'PAGES.HOME.ONLY-ON-TELOS-1' | translate }}
                <a href="https://telos.net/" target="_blank">
                    <img class='p-home__on-telos-image' src="assets/images/telos-logo-white.svg" alt="Telos">
                </a>
                {{ 'PAGES.HOME.ONLY-ON-TELOS-2' | translate }}
            </div>
        </div>
    `,
    styleUrls: ['./home.component.scss']
})
export class HomePage {

}
