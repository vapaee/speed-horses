import { Component, ViewEncapsulation } from '@angular/core';
import { SharedModule } from '@app/shared/shared.module';
import { UnderConstructionComponent } from '@app/components/under-construction/under-construction.component';

@Component({
    standalone: true,
    selector: 'app-accessories',
    imports: [SharedModule, UnderConstructionComponent],
    template: `
        <section class="p-accessories">
            <span class="p-accessories__title">{{ 'PAGES.SHOP.ACCESSORIES.NAME' | translate }}</span>
            <app-under-construction></app-under-construction>
        </section>
    `,
    styleUrls: ['./accessories.component.scss'],
    encapsulation: ViewEncapsulation.None
})
export class AccessoriesPage {}
