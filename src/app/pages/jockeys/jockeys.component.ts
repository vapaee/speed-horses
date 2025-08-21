import { Component, ViewEncapsulation } from '@angular/core';
import { SharedModule } from '@app/shared/shared.module';
import { UnderConstructionComponent } from '@app/components/under-construction/under-construction.component';

@Component({
    standalone: true,
    selector: 'app-jockeys',
    imports: [SharedModule, UnderConstructionComponent],
    template: `
        <section class="p-jockeys">
            <span class="p-jockeys__title">{{ 'PAGES.SHOP.JOCKEYS.NAME' | translate }}</span>
            <app-under-construction></app-under-construction>
        </section>
    `,
    styleUrls: ['./jockeys.component.scss'],
    encapsulation: ViewEncapsulation.None
})
export class JockeysPage {}
