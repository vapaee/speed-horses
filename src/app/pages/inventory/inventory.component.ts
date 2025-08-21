import { Component, ViewEncapsulation } from '@angular/core';
import { SharedModule } from '@app/shared/shared.module';
import { UnderConstructionComponent } from '@app/components/under-construction/under-construction.component';

@Component({
    standalone: true,
    selector: 'app-inventory',
    imports: [SharedModule, UnderConstructionComponent],
    template: `
        <section class="p-inventory">
            <span class="p-inventory__title">{{ 'PAGES.REFUGE.INVENTORY.NAME' | translate }}</span>
            <app-under-construction></app-under-construction>
        </section>
    `,
    styleUrls: ['./inventory.component.scss'],
    encapsulation: ViewEncapsulation.None
})
export class InventoryPage {}
