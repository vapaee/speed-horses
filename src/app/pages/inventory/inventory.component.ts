import { Component, ViewEncapsulation } from '@angular/core';
import { SharedModule } from '@app/shared/shared.module';

@Component({
    standalone: true,
    selector: 'app-inventory',
    imports: [SharedModule],
    template: `
        <section class="p-inventory">
            <span class="p-inventory__title">{{ 'PAGES.REFUGE.INVENTORY.NAME' | translate }}</span>
        </section>
    `,
    styleUrls: ['./inventory.component.scss'],
    encapsulation: ViewEncapsulation.None
})
export class InventoryPage {}
