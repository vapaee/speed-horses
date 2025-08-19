// src/app/pages/home/home.component.ts
import { Component } from '@angular/core';
import { SharedModule } from '@app/shared/shared.module';

@Component({
    standalone: true,
    selector: 'app-forge',
    imports: [SharedModule],
    template: `
        <section class="p-forge">
            <span class="p-forge__title">Forge</span>
        </section>
    `,
    styleUrls: ['./forge.component.scss']
})
export class ForgePage {

}
