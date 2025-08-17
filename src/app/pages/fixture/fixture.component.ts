import { Component } from '@angular/core';
import { SharedModule } from '@app/shared/shared.module';

@Component({
    standalone: true,
    selector: 'app-fixture',
    imports: [SharedModule],
    template: `
        <div class="p-fixture">
            <h1>{{ 'PAGES.FIXTURE.NAME' | translate }}</h1>
        </div>
    `,
    styleUrls: ['./fixture.component.scss']
})
export class FixtureComponent {}
