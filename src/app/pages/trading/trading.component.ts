// src/app/pages/home/home.component.ts
import { Component } from '@angular/core';
import { SharedModule } from '@app/shared/shared.module';
import { UnderConstructionComponent } from '@app/components/under-construction/under-construction.component';


@Component({
    standalone: true,
    selector: 'app-trading',
    imports: [SharedModule, UnderConstructionComponent],
    template: `
        <section class="p-trading">
            <span class="p-trading__title">Trading</span>
            <app-under-construction></app-under-construction>
        </section>
    `,
    styleUrls: ['./trading.component.scss']
})
export class TradingPage {

}
