import { Component } from '@angular/core';
import { SharedModule } from '@app/shared/shared.module';
import { UnderConstructionComponent } from '@app/components/under-construction/under-construction.component';

@Component({
    standalone: true,
    selector: 'app-fixture',
    imports: [SharedModule, UnderConstructionComponent],
    template: `
        <div class="p-fixture">
            <h1>{{ 'PAGES.FIXTURE.NAME' | translate }}</h1>
            <app-under-construction></app-under-construction>
        </div>
    `,
    styleUrls: ['./fixture.component.scss']
})
export class FixtureComponent {}
