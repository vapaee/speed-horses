// src/app/pages/home/home.component.ts
import { Component } from '@angular/core';
import { SharedModule } from '@app/shared/shared.module';


@Component({
    standalone: true,
    selector: 'app-trading',
    imports: [SharedModule],
    template: `
        <section class="sh-c1">
            <h2 class="sh-c1__title">Trading</h2>
        </section>
    `,
    styleUrls: ['./trading.component.scss']
})
export class TradingPage {

}
