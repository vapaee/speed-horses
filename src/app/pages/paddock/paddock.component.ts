import { Component, ViewEncapsulation } from '@angular/core';
import { SharedModule } from '@app/shared/shared.module';

@Component({
    standalone: true,
    selector: 'app-paddock',
    imports: [SharedModule],
    template: `
        <section class="p-paddock">
            <span class="p-paddock__title">{{ 'PAGES.REFUGE.PADDOCK.NAME' | translate }}</span>
        </section>
    `,
    styleUrls: ['./paddock.component.scss'],
    encapsulation: ViewEncapsulation.None
})
export class PaddockPage {}
