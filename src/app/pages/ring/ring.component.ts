import { Component, ViewEncapsulation } from '@angular/core';
import { SharedModule } from '@app/shared/shared.module';
import { UnderConstructionComponent } from '@app/components/under-construction/under-construction.component';

@Component({
    standalone: true,
    selector: 'app-ring',
    imports: [SharedModule, UnderConstructionComponent],
    template: `
        <section class="p-ring">
            <span class="p-ring__title">{{ 'PAGES.REFUGE.RING.NAME' | translate }}</span>
            <app-under-construction></app-under-construction>
        </section>
    `,
    styleUrls: ['./ring.component.scss'],
    encapsulation: ViewEncapsulation.None
})
export class RingPage {}
