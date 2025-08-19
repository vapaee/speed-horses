import { Component, ViewEncapsulation } from '@angular/core';
import { SharedModule } from '@app/shared/shared.module';

@Component({
    standalone: true,
    selector: 'app-horseshoes',
    imports: [SharedModule],
    template: `
        <section class="p-horseshoes">
            <span class="p-horseshoes__title">{{ 'PAGES.SHOP.SHOES.NAME' | translate }}</span>
        </section>
    `,
    styleUrls: ['./horseshoes.component.scss'],
    encapsulation: ViewEncapsulation.None
})
export class HorseshoesPage {}
