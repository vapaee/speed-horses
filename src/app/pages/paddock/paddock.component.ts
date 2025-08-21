import { Component, ViewEncapsulation } from '@angular/core';
import { SharedModule } from '@app/shared/shared.module';
import { UnderConstructionComponent } from '@app/components/under-construction/under-construction.component';

@Component({
    standalone: true,
    selector: 'app-paddock',
    imports: [SharedModule, UnderConstructionComponent],
    template: `
        <section class="p-paddock">
            <span class="p-paddock__title">{{ 'PAGES.REFUGE.PADDOCK.NAME' | translate }}</span>
            <app-under-construction></app-under-construction>
        </section>
    `,
    styleUrls: ['./paddock.component.scss'],
    encapsulation: ViewEncapsulation.None
})
export class PaddockPage {}
