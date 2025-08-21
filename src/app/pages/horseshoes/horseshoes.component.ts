import { Component, ViewEncapsulation } from '@angular/core';
import { SharedModule } from '@app/shared/shared.module';
import { UnderConstructionComponent } from '@app/components/under-construction/under-construction.component';

@Component({
    standalone: true,
    selector: 'app-horseshoes',
    imports: [SharedModule, UnderConstructionComponent],
    template: `
        <section class="p-horseshoes">
            <span class="p-horseshoes__title">{{ 'PAGES.SHOP.SHOES.NAME' | translate }}</span>
            <app-under-construction></app-under-construction>
        </section>
    `,
    styleUrls: ['./horseshoes.component.scss'],
    encapsulation: ViewEncapsulation.None
})
export class HorseshoesPage {}
