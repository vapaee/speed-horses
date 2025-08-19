import { Component, ViewEncapsulation } from '@angular/core';
import { SharedModule } from '@app/shared/shared.module';

@Component({
    standalone: true,
    selector: 'app-jockeys',
    imports: [SharedModule],
    template: `
        <section class="p-jockeys">
            <span class="p-jockeys__title">{{ 'PAGES.SHOP.JOCKEYS.NAME' | translate }}</span>
        </section>
    `,
    styleUrls: ['./jockeys.component.scss'],
    encapsulation: ViewEncapsulation.None
})
export class JockeysPage {}
