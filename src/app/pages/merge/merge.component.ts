import { Component, ViewEncapsulation } from '@angular/core';
import { SharedModule } from '@app/shared/shared.module';
import { UnderConstructionComponent } from '@app/components/under-construction/under-construction.component';

@Component({
    standalone: true,
    selector: 'app-merge',
    imports: [SharedModule, UnderConstructionComponent],
    template: `
        <section class="p-merge">
            <span class="p-merge__title">{{ 'PAGES.REFUGE.MERGE.NAME' | translate }}</span>
            <app-under-construction></app-under-construction>
        </section>
    `,
    styleUrls: ['./merge.component.scss'],
    encapsulation: ViewEncapsulation.None
})
export class MergePage {}
