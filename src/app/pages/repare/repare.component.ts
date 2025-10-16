import { Component, ViewEncapsulation } from '@angular/core';
import { SharedModule } from '@app/shared/shared.module';
import { UnderConstructionComponent } from '@app/components/under-construction/under-construction.component';

@Component({
    standalone: true,
    selector: 'app-repare',
    imports: [SharedModule, UnderConstructionComponent],
    template: `
        <section class="p-repare">
            <span class="p-repare__title">{{ 'PAGES.REFUGE.REPARE.NAME' | translate }}</span>
            <app-under-construction></app-under-construction>
        </section>
    `,
    styleUrls: ['./repare.component.scss'],
    encapsulation: ViewEncapsulation.None
})
export class ReparePage {}
