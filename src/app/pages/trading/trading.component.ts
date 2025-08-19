// src/app/pages/home/home.component.ts
import { Component } from '@angular/core';
import { SharedModule } from '@app/shared/shared.module';


@Component({
    standalone: true,
    selector: 'app-trading',
    imports: [SharedModule],
    template: `
        <section class="p-trading">
            <span class="p-trading__title">Trading</span>
        </section>
    `,
    styleUrls: ['./trading.component.scss']
})
export class TradingPage {

}
