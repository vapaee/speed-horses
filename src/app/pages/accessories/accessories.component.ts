import { Component, ViewEncapsulation } from '@angular/core';
import { SharedModule } from '@app/shared/shared.module';

@Component({
    standalone: true,
    selector: 'app-accessories',
    imports: [SharedModule],
    template: `
        <section class="p-accessories">
            <span class="p-accessories__title">{{ 'PAGES.SHOP.HORSE.NAME' | translate }}</span>
        </section>
    `,
    styleUrls: ['./accessories.component.scss'],
    encapsulation: ViewEncapsulation.None
})
export class AccessoriesPage {}
