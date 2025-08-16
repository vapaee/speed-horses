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
                <img class="p-home__logo" src="assets/game-img/gold-horse.png" alt="vortdex" />
                <div class="p-home__title">{{ 'PAGES.HOME.TITLE' | translate }}</div>
            </div>
            <p class="p-home__subtitle">{{ 'PAGES.HOME.DESCRIPTION' | translate }}</p>
        </div>
    `,
    styleUrls: ['./home.component.scss']
})
export class HomeComponent {

}
